{
  pkgs,
  self,
  lib,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  inventory = self.lib.inventory;
  hostIds = lib.attrNames self.nixosConfigurations;
  configFor = hostId: self.nixosConfigurations.${hostId}.config;
  ownerUsernameFor =
    hostId:
    let
      ownerId = inventory.hosts.${hostId}.ownership.owner;
    in
    inventory.users.${ownerId}.system_account.username;
  passwordAccountFor =
    hostId:
    let
      roles = inventory.hosts.${hostId}.roles;
    in
    if lib.elem "personal-laptop" roles then
      "owner"
    else if
      lib.any (role: lib.elem role roles) [
        "personal-server-dev"
        "cloud-vps-control"
      ]
    then
      "root"
    else
      throw "bootstrap-secrets: no password account policy for ${hostId}";
  everyHost = predicate: lib.all (hostId: predicate hostId (configFor hostId)) hostIds;

  passwordRecipient = lib.removeSuffix "\n" (
    builtins.readFile (self + /secrets/bootstrap/password.age.pub)
  );
  tailscaleRecipient = lib.removeSuffix "\n" (
    builtins.readFile (self + /secrets/bootstrap/tailscale.age.pub)
  );
  passwordSops = builtins.readFile (self + /secrets/bootstrap/password.yaml);
  tailscaleSops = builtins.readFile (self + /secrets/bootstrap/tailscale.yaml);
  passwordIdentityPath = self + /secrets/bootstrap/password.age.key.enc;
  tailscaleIdentityPath = self + /secrets/bootstrap/tailscale.age.key.enc;
  passwordIdentityExists = builtins.pathExists passwordIdentityPath;
  tailscaleIdentityExists = builtins.pathExists tailscaleIdentityPath;
  passwordIdentity = if passwordIdentityExists then builtins.readFile passwordIdentityPath else "";
  tailscaleIdentity = if tailscaleIdentityExists then builtins.readFile tailscaleIdentityPath else "";

  checks = {
    password-account-policy = everyHost (
      hostId: config:
      let
        owner = config.users.users.${ownerUsernameFor hostId};
        root = config.users.users.root;
        account = passwordAccountFor hostId;
      in
      config.services.sops.bootstrap.passwordAccount == account
      && !config.users.mutableUsers
      && (
        if account == "owner" then
          owner.hashedPassword == null
          && owner.hashedPasswordFile == "/run/bootstrap-secrets/password-hash"
          && root.hashedPassword == "!"
          && root.hashedPasswordFile == null
        else
          owner.hashedPassword == "!"
          && owner.hashedPasswordFile == null
          && root.hashedPassword == null
          && root.hashedPasswordFile == "/run/bootstrap-secrets/password-hash"
      )
    );
    password-runs-before-users = everyHost (
      _hostId: config: lib.elem "bootstrapPassword" config.system.activationScripts.users.deps
    );
    tailscale-is-independent = everyHost (
      _hostId: config:
      !config.services.tailscale.useAuthKey
      && config.services.tailscale.authKeyFile == "/run/tailscale-bootstrap/preauth-key"
      && !(builtins.hasAttr "tailscale-key" config.sops.secrets)
      && lib.elem "tailscale-bootstrap-secret.service" config.systemd.services.tailscaled-autoconnect.requires
    );
    tailscale-key-stays-file-backed = everyHost (
      _hostId: config:
      let
        service = config.systemd.services.tailscaled-autoconnect;
        script = config.systemd.services.tailscaled-autoconnect.script;
      in
      service.serviceConfig.LoadCredential == [
        "auth-key:/run/tailscale-bootstrap/preauth-key"
      ]
      && lib.hasInfix ''--auth-key "file:$auth_key_file"'' script
      && !lib.hasInfix "cat /run/tailscale-bootstrap/preauth-key" script
      && lib.elem "--reset" config.services.tailscale.extraUpFlags
      && service.serviceConfig.TimeoutStartSec == "60s"
    );
    munge-is-system-scoped =
      (inventory.clusters.personal.secret_paths or { }) == { }
      && everyHost (
        _hostId: config:
        let
          munge = config.sops.secrets."munge-key";
        in
        toString munge.sopsFile == toString (self + /secrets/system.yaml)
        && munge.key == "munge-key"
        && munge.path == "/etc/munge/munge.key"
      );
    ssh-is-key-only = everyHost (
      _hostId: config:
      config.services.openssh.settings.PasswordAuthentication == false
      && config.services.openssh.settings.KbdInteractiveAuthentication == false
      && config.services.openssh.settings.PermitRootLogin == "no"
    );
    sudo-follows-host-policy = everyHost (
      hostId: config:
      let
        usesRootPassword = lib.hasInfix "Defaults:%wheel rootpw" config.security.sudo.extraConfig;
      in
      if passwordAccountFor hostId == "root" then
        config.security.sudo.wheelNeedsPassword && usesRootPassword
      else
        config.security.sudo.wheelNeedsPassword && !usesRootPassword
    );
    recipients-are-distinct =
      lib.hasPrefix "age1" passwordRecipient
      && lib.hasPrefix "age1" tailscaleRecipient
      && passwordRecipient != tailscaleRecipient;
    ciphertexts-use-own-recipient =
      lib.hasInfix passwordRecipient passwordSops
      && !lib.hasInfix tailscaleRecipient passwordSops
      && lib.hasInfix tailscaleRecipient tailscaleSops
      && !lib.hasInfix passwordRecipient tailscaleSops;
    password-envelope-exists = passwordIdentityExists;
    tailscale-envelope-exists = tailscaleIdentityExists;
    identities-are-passphrase-encrypted =
      (
        !passwordIdentityExists
        || (
          lib.hasPrefix "-----BEGIN AGE ENCRYPTED FILE-----" passwordIdentity
          && !lib.hasInfix "AGE-SECRET-KEY-" passwordIdentity
        )
      )
      && (
        !tailscaleIdentityExists
        || (
          lib.hasPrefix "-----BEGIN AGE ENCRYPTED FILE-----" tailscaleIdentity
          && !lib.hasInfix "AGE-SECRET-KEY-" tailscaleIdentity
        )
      );
    deploy-tool-exists = builtins.hasAttr "bootstrap-deploy" self.packages.${system};
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
pkgs.runCommand "bootstrap-secrets-contract"
  {
    failureCount = toString (lib.length failures);
    failureNames = lib.concatStringsSep "," failures;
  }
  ''
    if [[ "$failureCount" != 0 ]]; then
      echo "failed bootstrap secret checks: $failureNames" >&2
      exit 1
    fi
    touch "$out"
  ''
