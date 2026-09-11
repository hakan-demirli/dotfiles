{
  config,
  inputs,
  cluster,
  lib,
  pkgs,
  host,
  ...
}:
let
  cfg = config.services.sops.bootstrap;
  inherit (cfg) passwordSopsFile;
  ownerId =
    if host.ownership.owner == null then
      throw "bootstrap-authentication: host '${host.id}' requires ownership.owner"
    else
      host.ownership.owner;
  owner =
    cluster.users.${ownerId}
      or (throw "bootstrap-authentication: host '${host.id}' owner '${ownerId}' is not an inventory user");
  ownerUsername =
    if owner.system_account == null then
      throw "bootstrap-authentication: host '${host.id}' owner '${ownerId}' requires a system account"
    else
      owner.system_account.username;
  passwordIsOwner = cfg.passwordAccount == "owner";
  passwordSecretAccount = if passwordIsOwner then ownerId else "root";
  passwordUsername = if passwordIsOwner then ownerUsername else "root";
  lockedUsername = if passwordIsOwner then "root" else ownerUsername;
  impermanenceEnabled = host.impermanence.enable or false;
  passwordHashPath = "/run/bootstrap-secrets/password-hash";

  installPassword = pkgs.writeShellApplication {
    name = "install-bootstrap-password";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sops
    ];
    text = ''
      key_file=${lib.escapeShellArg cfg.passwordKeyFile}
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
in
{
  options.services.sops.bootstrap = {
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
  };

  config = {
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
    };

    environment.persistence = lib.mkIf impermanenceEnabled {
      "/persist/system".directories = [ "/var/lib/sops-nix" ];
    };
  };
}
