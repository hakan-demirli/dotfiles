{
  config,
  inputs,
  lib,
  pkgs,
  host ? null,
  cluster ? null,
  ...
}:
let
  inherit (lib)
    attrValues
    elemAt
    findFirst
    last
    length
    listToAttrs
    mapAttrsToList
    optional
    splitString
    ;

  sopsFile = inputs.self + /secrets/secrets.yaml;

  ownerId = if host == null then null else (host.ownership.owner or null);
  ownerUser = if ownerId == null || cluster == null then null else (cluster.users.${ownerId} or null);
  primaryAccount = if ownerUser == null then null else ownerUser.system_account;
  defaultUsername = if primaryAccount == null then "emre" else primaryAccount.username;

  cfg = config.services.sops;
  inherit (cfg) username;

  mkPubKey = path: content: "L+ ${path} - - - - ${pkgs.writeText (baseNameOf path) content}";

  inventoryUser = findFirst (
    u: u.system_account != null && u.system_account.username == username
  ) null (attrValues inputs.self.lib.inventory.users);

  sshKeys = if inventoryUser == null then [ ] else inventoryUser.keys.ssh;

  parseKey =
    key:
    let
      parts = splitString " " key;
      comment = if length parts >= 3 then elemAt parts 2 else "";
      atParts = splitString "@" comment;
    in
    {
      label = if length atParts >= 2 then last atParts else "main";
      inherit key;
    };

  parsed = map parseKey sshKeys;

  keyByLabel = listToAttrs (
    map (p: {
      name = p.label;
      value = p.key;
    }) parsed
  );

  pubKeyFile =
    label:
    if label == "main" then
      "/home/${username}/.ssh/id_ed25519.pub"
    else
      "/home/${username}/.ssh/id_ed25519_${label}.pub";

  pubKeyTmpfiles = mapAttrsToList (label: key: mkPubKey (pubKeyFile label) key) keyByLabel;

  signKey = keyByLabel.sign or null;
  signingPubKey = pubKeyFile "sign";
  allowedSignersFile = "/home/${username}/.config/git/allowed_signers";

  gitSignConfigFile = ''
    [user]
      signingkey = ${signingPubKey}
    [gpg]
      format = ssh
    [gpg "ssh"]
      allowedSignersFile = ${allowedSignersFile}
    [commit]
      gpgsign = true
  '';

  allowedSignersContent = ''
    ${username} namespaces="git" ${signKey}
  '';

  gitSigningTmpfiles =
    optional (signKey != null) (mkPubKey allowedSignersFile allowedSignersContent)
    ++ optional (signKey != null) (mkPubKey "/home/${username}/.config/git/git_sign" gitSignConfigFile);
in
{
  options.services.sops = {
    username = lib.mkOption {
      type = lib.types.str;
      default = defaultUsername;
    };
    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/persist/system/var/lib/sops-nix/key.txt";
      description = ''
        Path to the sops age keyfile on the host. The file may contain
        MULTIPLE age private keys (one AGE-SECRET-KEY-... per line). sops
        tries each in turn, so the operator can append both the shared
        bootstrap key (decrypted from secrets/age-bootstrap.key.enc) and
        any per-host key derived from ssh-to-age of /etc/ssh/ssh_host_*.
      '';
    };
  };

  config = {
    sops = {
      defaultSopsFile = sopsFile;
      defaultSopsFormat = "yaml";
      age.keyFile = cfg.ageKeyFile;

      secrets = {
        "ssh/id_ed25519" = {
          owner = username;
          path = "/home/${username}/.ssh/id_ed25519";
          mode = "0600";
        };
        "ssh/id_ed25519_proton" = {
          owner = username;
          path = "/home/${username}/.ssh/id_ed25519_proton";
          mode = "0600";
        };
        "root_id_ed25519_proton" = {
          key = "ssh/id_ed25519_proton";
          owner = "root";
          path = "/root/.ssh/id_ed25519_proton";
          mode = "0600";
        };
        "ssh/id_ed25519_sf" = {
          owner = username;
          path = "/home/${username}/.ssh/id_ed25519_sf";
          mode = "0600";
        };
        "ssh/id_ed25519_sign" = {
          owner = username;
          path = "/home/${username}/.ssh/id_ed25519_sign";
          mode = "0600";
        };
        "ssh/gh_action_key" = {
          owner = username;
          path = "/home/${username}/.ssh/gh_action_key";
          mode = "0600";
        };

        "git_tokens" = {
          owner = username;
          path = "/home/${username}/.config/git/git_tokens";
        };
        "git_users" = {
          owner = username;
          path = "/home/${username}/.config/git/git_users";
        };

        "nixauth" = {
          owner = username;
          path = "/home/${username}/.config/nix/nixauth";
        };

        "environment" = {
          owner = username;
          path = "/home/${username}/.config/secrets/environment";
        };
        "questa_license.dat" = {
          owner = username;
          path = "/home/${username}/.config/secrets/questa_license.dat";
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /home/${username}/.ssh 0700 ${username} users -"
      "d /home/${username}/.config 0755 ${username} users -"
      "d /home/${username}/.config/git 0755 ${username} users -"
      "d /home/${username}/.config/nix 0755 ${username} users -"
      "d /home/${username}/.config/secrets 0755 ${username} users -"
      "d /root/.ssh 0700 root root -"
    ]
    ++ pubKeyTmpfiles
    ++ gitSigningTmpfiles;

    environment.persistence."/persist/system".directories = [
      "/var/lib/sops-nix"
    ];

    assertions = [
      {
        assertion = inventoryUser != null;
        message = "services.sops.username = ${username} but no inventory user with that system_account.username was found.";
      }
    ];
  };
}
