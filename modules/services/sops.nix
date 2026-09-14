{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  sopsFile = builtins.path {
    path = inputs.self + /secrets/system.yaml;
    name = "system.yaml";
  };
  tailscaleSopsFile = builtins.path {
    path = inputs.self + /secrets/bootstrap/tailscale.yaml;
    name = "tailscale.yaml";
  };

  cfg = config.services.sops;
  tailscaleAuthKeyPath = "/run/tailscale-bootstrap/preauth-key";

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
  imports = [ ./bootstrap-authentication.nix ];

  options.services.sops = {
    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/persist/system/var/lib/sops-nix/key.txt";
    };
    bootstrap.tailscaleKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/persist/system/var/lib/sops-nix/bootstrap-tailscale.key";
      description = "Optional age identity used only for the Headscale bootstrap preauth key.";
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

    system.activationScripts.warnMissingSopsKey = lib.stringAfter [ "specialfs" ] ''
      if [[ ! -e ${lib.escapeShellArg cfg.ageKeyFile} ]]; then
        echo "warning: SOPS age key ${cfg.ageKeyFile} not found. Skipping system secret deployment" >&2
      fi
    '';

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

    systemd.tmpfiles.rules = [ "d /root/.ssh 0700 root root -" ];
  };
}
