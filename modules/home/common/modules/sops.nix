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
  inherit (inputs.self.lib) forge;
  inherit (config.sops) placeholder;
  gitCredentialHelper = pkgs.writeShellApplication {
    name = "git-credential-sops-readonly";
    runtimeInputs = [ pkgs.git ];
    text = ''
      case "''${1:-}" in
        get)
          store_file=${lib.escapeShellArg config.sops.templates.git_tokens.path}
          if [[ -r "$store_file" ]]; then
            exec git credential-store --file "$store_file" get
          fi
          ;;
        store | erase) ;;
      esac
    '';
  };
  bootstrap = pkgs.writeShellScriptBin "bootstrap-home-secrets" ''
    exec ${pkgs.coreutils}/bin/env \
      ${
        lib.concatStringsSep " " (
          lib.mapAttrsToList (name: value: lib.escapeShellArg "${name}=${value}") config.sops.environment
        )
      } \
      ${lib.escapeShellArg (builtins.head config.systemd.user.services.sops-nix.Service.ExecStart)}
  '';
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  options.homeSops = {
    enable = lib.mkEnableOption "personal Home Manager secrets";
    bootstrap = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "The configured secret installer and read-only Git credential helper.";
    };
    identity = lib.mkOption {
      type = lib.types.str;
    };
    ageKeyFile = lib.mkOption {
      type = lib.types.str;
      default = "${cfgHome}/sops/age/keys.txt";
    };
  };

  config = lib.mkIf cfg.enable {
    homeSops.bootstrap = pkgs.symlinkJoin {
      name = "home-secrets-bootstrap";
      paths = [
        bootstrap
        gitCredentialHelper
      ];
    };
    home = {
      packages = [ gitCredentialHelper ];
      activation.checkSopsKey = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        if [[ ! -s ${lib.escapeShellArg cfg.ageKeyFile} ]]; then
          echo "SOPS age key ${cfg.ageKeyFile} is missing. Run: nix run path:.#deploy-home-secrets" >&2
          exit 1
        fi
      '';
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
        "github/token" = { };
        "gitlab/token" = { };
        "forgejo/token" = { };
        "git_users" = {
          path = "${cfgHome}/git/git_users";
        };
        "environment" = { };
        "questa_license.dat" = {
          path = "${cfgHome}/secrets/questa_license.dat";
        };
        "claude/ehd" = {
          path = "${cfgHome}/secrets/claude/ehd";
          mode = "0400";
        };
        "claude/etz" = {
          path = "${cfgHome}/secrets/claude/etz";
          mode = "0400";
        };
        "cliproxyapi/api-key" = {
          path = "${cfgHome}/secrets/cliproxyapi/api-key";
          mode = "0400";
        };
      };

      templates = {
        "git_tokens" = {
          path = "${cfgHome}/sops-nix/secrets/git_tokens";
          content = ''
            https://${forge.owner}:${placeholder."github/token"}@github.com
            https://${forge.owner}:${placeholder."gitlab/token"}@gitlab.com
            http://${forge.owner}:${placeholder."forgejo/token"}@${forge.site}
          '';
        };
        "nixauth" = {
          path = "${cfgHome}/nix/nixauth";
          content = ''
            access-tokens = github.com=${placeholder."github/token"}
          '';
        };
        "environment" = {
          path = "${cfgHome}/secrets/environment";
          content = ''
            ${placeholder.environment}
            GH_TOKEN=${placeholder."github/token"}
          '';
        };
      };
    };

    systemd.user.services.sops-nix.Unit.AssertFileNotEmpty = cfg.ageKeyFile;
  };
}
