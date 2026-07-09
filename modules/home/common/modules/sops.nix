{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.homeSops;
  homeDir = config.home.homeDirectory;
  cfgHome = "${homeDir}/.config";
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  options.homeSops = {
    identity = lib.mkOption {
      type = lib.types.str;
    };
    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${cfgHome}/sops/age/keys.txt";
    };
  };

  config = {
    sops = {
      defaultSopsFile = ../../users + "/${cfg.identity}/secrets/secrets.yaml";
      defaultSopsFormat = "yaml";
      age.keyFile = cfg.ageKeyFile;

      secrets = {
        "ssh/id_ed25519" = {
          path = "${homeDir}/.ssh/id_ed25519";
          mode = "0600";
        };
        "ssh/id_ed25519_proton" = {
          path = "${homeDir}/.ssh/id_ed25519_proton";
          mode = "0600";
        };
        "ssh/id_ed25519_sf" = {
          path = "${homeDir}/.ssh/id_ed25519_sf";
          mode = "0600";
        };
        "git_tokens" = {
          path = "${cfgHome}/git/git_tokens";
        };
        "git_users" = {
          path = "${cfgHome}/git/git_users";
        };
        "nixauth" = {
          path = "${cfgHome}/nix/nixauth";
        };
        "environment" = {
          path = "${cfgHome}/secrets/environment";
        };
        "questa_license.dat" = {
          path = "${cfgHome}/secrets/questa_license.dat";
        };
      };
    };
  };
}
