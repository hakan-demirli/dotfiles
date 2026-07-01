{
  config,
  inputs,
  cluster,
  lib,
  pkgs,
  host ? null,
  ...
}:
let
  sopsFile = inputs.self + /secrets/system.yaml;
  tailscaleSopsFile = inputs.self + /secrets/bootstrap/tailscale.yaml;

  cfg = config.services.sops;
  passwordSopsFile = cfg.bootstrap.passwordSopsFile;
  ownerId = host.ownership.owner;
  ownerUsername = cluster.users.${ownerId}.system_account.username;
  passwordIsOwner = cfg.bootstrap.passwordAccount == "owner";
  passwordSecretAccount = if passwordIsOwner then ownerId else "root";
  passwordUsername = if passwordIsOwner then ownerUsername else "root";
  lockedUsername = if passwordIsOwner then "root" else ownerUsername;
  impermanenceEnabled = host != null && (host.impermanence.enable or false);
  passwordHashPath = "/run/bootstrap-secrets/password-hash";
  tailscaleAuthKeyPath = "/run/tailscale-bootstrap/preauth-key";

  installPassword = pkgs.writeShellApplication {
    name = "install-bootstrap-password";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sops
    ];
    text = ''
      key_file=${lib.escapeShellArg cfg.bootstrap.passwordKeyFile}
      output_file=${lib.escapeShellArg passwordHashPath}

      if [[ ! -s "$key_file" ]]; then
        echo "fatal: mandatory password bootstrap key is missing: $key_file" >&2
        echo "deploy it before nixos-install. Refusing to activate a system without its privilege password" >&2
        exit 1
      fi

      install -d -m 0700 "$(dirname "$output_file")"
      staged="$(mktemp "$(dirname "$output_file")/.password-hash.XXXXXX")"
      trap 'rm -f "$staged"' EXIT

      if ! SOPS_AGE_KEY_FILE="$key_file" sops --decrypt \
        --extract ${lib.escapeShellArg "[\"hosts\"][\"${host.id}\"][\"${passwordSecretAccount}\"][\"password-hash\"]"} \
        ${passwordSopsFile} > "$staged"; then
        echo "fatal: cannot decrypt the mandatory password bootstrap secret" >&2
        exit 1
      fi

      password_hash="$(<"$staged")"
      if [[ ! $password_hash =~ ^\$(y|2a|2b|2y|5|6)\$ ]]; then
        echo "fatal: password bootstrap secret is not a supported password hash" >&2
        exit 1
      fi

      chmod 0400 "$staged"
      mv -f "$staged" "$output_file"
      trap - EXIT
    '';
  };

  installTailscaleBootstrap = pkgs.writeShellApplication {
    name = "install-tailscale-bootstrap-secret";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sops
    ];
    text = ''
      key_file=${lib.escapeShellArg cfg.bootstrap.tailscaleKeyFile}
      output_file=${lib.escapeShellArg tailscaleAuthKeyPath}
      rm -f "$output_file"

      if [[ ! -s "$key_file" ]]; then
        echo "warning: optional Tailscale bootstrap key is missing: $key_file" >&2
        echo "warning: automatic Headscale enrollment is disabled" >&2
        exit 0
      fi

      staged="$(mktemp "$(dirname "$output_file")/.preauth-key.XXXXXX")"
      trap 'rm -f "$staged"' EXIT

      if ! SOPS_AGE_KEY_FILE="$key_file" sops --decrypt \
        --extract ${lib.escapeShellArg ''["headscale"]["bootstrap-preauth-key"]''} \
        ${tailscaleSopsFile} > "$staged"; then
        echo "warning: optional Tailscale bootstrap secret could not be decrypted" >&2
        echo "warning: automatic Headscale enrollment is disabled" >&2
        exit 0
      fi

      if [[ ! -s "$staged" ]]; then
        echo "warning: optional Headscale bootstrap preauth key is empty" >&2
        echo "warning: automatic Headscale enrollment is disabled" >&2
        exit 0
      fi

      chmod 0400 "$staged"
      mv -f "$staged" "$output_file"
      trap - EXIT
    '';
  };
in
{
  options.services.sops = {
    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/persist/system/var/lib/sops-nix/key.txt";
    };
    bootstrap = {
      passwordAccount = lib.mkOption {
        type = lib.types.enum [
          "owner"
          "root"
        ];
        description = "Account receiving the mandatory bootstrap password hash on this host.";
      };
      passwordKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/persist/system/var/lib/sops-nix/bootstrap-password.key";
        description = "Mandatory age identity used only for the host privilege password bootstrap secret.";
      };
      passwordSopsFile = lib.mkOption {
        type = lib.types.path;
        default = inputs.self + /secrets/bootstrap/password.yaml;
        description = "SOPS file containing host-scoped bootstrap password hashes.";
      };
      tailscaleKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/persist/system/var/lib/sops-nix/bootstrap-tailscale.key";
        description = "Optional age identity used only for the Headscale bootstrap preauth key.";
      };
    };
  };

  config = {
    sops = {
      defaultSopsFile = sopsFile;
      defaultSopsFormat = "yaml";
      age.keyFile = cfg.ageKeyFile;
      useSystemdActivation = true;

      secrets = {
        "ssh/id_ed25519_proton" = {
          owner = "root";
          path = "/root/.ssh/id_ed25519_proton";
          mode = "0600";
        };
        "munge-key" = {
          owner = "munge";
          group = "munge";
          path = "/etc/munge/munge.key";
          mode = "0400";
        };
      };
    };

    users = {
      mutableUsers = false;
      users = {
        ${passwordUsername}.hashedPasswordFile = passwordHashPath;
        ${lockedUsername}.hashedPassword = "!";
      };
    };

    system.activationScripts = {
      bootstrapPassword = {
        deps = [ "specialfs" ];
        text = ''
          ${installPassword}/bin/install-bootstrap-password || exit $?
        '';
      };
      users.deps = lib.mkAfter [ "bootstrapPassword" ];
      warnMissingSopsKey = lib.stringAfter [ "specialfs" ] ''
        if [[ ! -e ${lib.escapeShellArg cfg.ageKeyFile} ]]; then
          echo "warning: SOPS age key ${cfg.ageKeyFile} not found. Skipping system secret deployment" >&2
        fi
      '';
    };

    services.tailscale = {
      useAuthKey = lib.mkForce false;
      authKeyFile = tailscaleAuthKeyPath;
    };

    systemd.services = {
      sops-install-secrets.unitConfig.ConditionPathExists = cfg.ageKeyFile;

      tailscale-bootstrap-secret = {
        description = "Decrypt the optional Headscale bootstrap preauth key";
        wantedBy = [ "multi-user.target" ];
        before = [ "tailscaled-autoconnect.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "tailscale-bootstrap";
          RuntimeDirectoryMode = "0700";
          ExecStart = "${installTailscaleBootstrap}/bin/install-tailscale-bootstrap-secret";
          StandardOutput = "journal+console";
          StandardError = "journal+console";
        };
      };

      tailscaled-autoconnect = {
        requires = [ "tailscale-bootstrap-secret.service" ];
        after = [ "tailscale-bootstrap-secret.service" ];
        unitConfig.ConditionPathExists = tailscaleAuthKeyPath;
      };
    };

    systemd.tmpfiles.rules = [
      "d /root/.ssh 0700 root root -"
    ];

    environment.persistence = lib.mkIf impermanenceEnabled {
      "/persist/system".directories = [
        "/var/lib/sops-nix"
      ];
    };
  };
}
