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
  lockedUsername = if passwordIsOwner then "root" else ownerUsername;
  impermanenceEnabled = host.impermanence.enable or false;
  passwordHashPath = secretAccount: "/run/bootstrap-secrets/${secretAccount}/password-hash";
  sudoGuests = lib.filterAttrs (id: account: id != ownerId && account.sudo_capable) (
    (inputs.infra-lib.lib.mkAccounts { inherit lib; }).onHost cluster host.id
  );

  installPasswords = pkgs.writeShellApplication {
    name = "install-bootstrap-passwords";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sops
    ];
    text = ''
      key_file=${lib.escapeShellArg cfg.passwordKeyFile}
      staged=
      trap '[[ -z "$staged" ]] || rm -f "$staged"' EXIT

      if [[ ! -s "$key_file" ]]; then
        echo "fatal: mandatory password bootstrap key is missing: $key_file" >&2
        echo "deploy it before nixos-install. Refusing to activate a system without its privilege password" >&2
        exit 1
      fi

      install_password() {
        local account=$1
        local selector=$2
        local output_file=$3
        local password_hash

        install -d -m 0700 "$(dirname "$output_file")"
        staged="$(mktemp "$(dirname "$output_file")/.password-hash.XXXXXX")"

        if ! SOPS_AGE_KEY_FILE="$key_file" sops --decrypt --extract "$selector" \
          ${passwordSopsFile} > "$staged"; then
          echo "fatal: cannot decrypt the mandatory password bootstrap secret for $account" >&2
          exit 1
        fi

        password_hash="$(<"$staged")"
        if [[ ! $password_hash =~ ^\$(y|2a|2b|2y|5|6)\$ ]]; then
          echo "fatal: password bootstrap secret for $account is not a supported password hash" >&2
          exit 1
        fi

        chmod 0400 "$staged"
        mv -f "$staged" "$output_file"
        staged=
      }

      ${lib.concatStrings (
        lib.mapAttrsToList (account: _: ''
          install_password ${lib.escapeShellArg account} ${lib.escapeShellArg "[\"hosts\"][\"${host.id}\"][\"${account}\"][\"password-hash\"]"} ${lib.escapeShellArg (passwordHashPath account)}
        '') cfg.passwordAccounts
      )}
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
    passwordAccounts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default =
        if passwordIsOwner then
          { ${ownerId} = ownerUsername; } // lib.mapAttrs (_: account: account.account.username) sudoGuests
        else
          { root = "root"; };
      defaultText = lib.literalMD "the owner and every other sudo-capable account, or root";
      description = "Password envelope accounts installed on this host, mapped to their local usernames.";
    };
    passwordKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/persist/system/var/lib/sops-nix/bootstrap-password.key";
      description = "Mandatory age identity used only for the host privilege password bootstrap secret.";
    };
    passwordSopsFile = lib.mkOption {
      type = lib.types.path;
      default = builtins.path {
        path = inputs.self + /secrets/bootstrap/password.yaml;
        name = "password.yaml";
      };
      description = "SOPS file containing host-scoped bootstrap password hashes.";
    };
  };

  config = {
    users = {
      mutableUsers = false;
      users =
        lib.mapAttrs' (
          account: username: lib.nameValuePair username { hashedPasswordFile = passwordHashPath account; }
        ) cfg.passwordAccounts
        // {
          ${lockedUsername}.hashedPassword = "!";
        };
    };

    system.activationScripts = {
      bootstrapPassword = {
        deps = [ "specialfs" ];
        text = ''
          ${installPasswords}/bin/install-bootstrap-passwords || exit $?
        '';
      };
      users.deps = lib.mkAfter [ "bootstrapPassword" ];
    };

    environment.persistence = lib.mkIf impermanenceEnabled {
      "/persist/system".directories = [ "/var/lib/sops-nix" ];
    };
  };
}
