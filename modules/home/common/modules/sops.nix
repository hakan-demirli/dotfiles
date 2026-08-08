{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homeSops;
  homeDir = config.home.homeDirectory;
  cfgHome = "${homeDir}/.config";
  sopsFile = ../../users + "/${cfg.identity}/secrets/secrets.yaml";
  gitCredentialHelper = pkgs.writeShellApplication {
    name = "git-credential-sops-readonly";
    runtimeInputs = [ pkgs.git ];
    text = ''
      case "''${1:-}" in
        get)
          store_file=${lib.escapeShellArg config.sops.secrets.git_tokens.path}
          if [[ -r "$store_file" ]]; then
            exec git credential-store --file "$store_file" get
          fi
          ;;
        store | erase) ;;
      esac
    '';
  };
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
    home = {
      packages = [ gitCredentialHelper ];
      activation = {
        warnMissingSopsKey = lib.hm.dag.entryBefore [ "sops-nix" ] ''
          if [[ ! -e ${lib.escapeShellArg cfg.ageKeyFile} ]]; then
            echo "warning: SOPS age key ${cfg.ageKeyFile} not found. Skipping secret deployment" >&2
          fi
        '';
        removeGitTokenUrlRewrite = lib.hm.dag.entryAfter [ "sops-nix" ] ''
          run ${pkgs.coreutils}/bin/rm -f ${lib.escapeShellArg "${cfgHome}/git/git_tokens"}
        '';
      };
    };

    sops = {
      defaultSopsFile = sopsFile;
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
        "ssh/id_ed25519_gitlab_ethz" = {
          path = "${homeDir}/.ssh/id_ed25519_gitlab_ethz";
          mode = "0600";
        };
        "git_tokens" = {
          mode = "0400";
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

    systemd.user.services.sops-nix.Unit.ConditionPathExists = cfg.ageKeyFile;
  };
}
