{
  config,
  inputs,
  lib,
  ...
}:
let
  sopsFile = inputs.self + /secrets/system.yaml;

  cfg = config.services.sops;
in
{
  options.services.sops = {
    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "/persist/system/var/lib/sops-nix/key.txt";
    };
  };

  config = {
    sops = {
      defaultSopsFile = sopsFile;
      defaultSopsFormat = "yaml";
      age.keyFile = cfg.ageKeyFile;

      secrets = {
        "ssh/id_ed25519_proton" = {
          owner = "root";
          path = "/root/.ssh/id_ed25519_proton";
          mode = "0600";
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /root/.ssh 0700 root root -"
    ];

    environment.persistence."/persist/system".directories = [
      "/var/lib/sops-nix"
    ];
  };
}
