{
  pkgs,
  self,
  lib,
  inputs,
}:
let
  laptopNames = [
    "laptop-0"
    "laptop-1"
  ];
  headlessNames = [
    "server-dev-1"
    "vps-oracle-0"
  ];
  trustedNames = laptopNames ++ headlessNames;
  borrowedNames = [
    "server-dev-2"
    "shared-server-1"
  ];
  homes = self.homeConfigurations;
  futureHost = self.lib.inventory.hosts.server-dev-1 // {
    id = "server-dev-999";
  };
  futureHomes = (import ../../../home/common/lib.nix).mkHomeConfigurations {
    homeRoot = self + "/modules/home/users";
    inputs = inputs // {
      self = self // {
        lib = self.lib // {
          inventory = self.lib.inventory // {
            hosts = self.lib.inventory.hosts // {
              server-dev-999 = futureHost;
            };
          };
          hostFacts = self.lib.hostFacts // {
            server-dev-999 = self.lib.hostFacts.server-dev-1 // {
              inherit (futureHost) id;
            };
          };
        };
      };
    };
  };
  trusted = map (name: homes."emre@${name}") trustedNames;
  restricted =
    map (name: homes."emre@${name}") borrowedNames
    ++ map (name: homes."user-0@${name}") [
      "desktop"
      "desktop-nvidia"
      "headless"
    ];
  checks = {
    new-inventory-host-is-automatic =
      futureHomes."emre@server-dev-999".config.home.stateRepository.branch == "hosts/server-dev-999"
      && futureHomes."emre@server-dev-999".config.homeSops.enable;
    native-aliases-match = lib.all (
      name:
      homes."emre@${name}".activationPackage.drvPath == homes."user-0@${name}".activationPackage.drvPath
    ) (trustedNames ++ borrowedNames);
    actual-host-identities = lib.all (
      name: homes."emre@${name}".config.home.sessionVariables.DOTFILES_HOST == name
    ) (trustedNames ++ borrowedNames);
    trusted-hosts-have-personal-state = lib.all (
      home:
      home.config.homeSops.enable
      && home.config.systemd.user.services ? state-backup
      && home.config.home.stateRepository.path == "/home/emre/.local/share/state"
      && home.config.sops.secrets ? git_tokens
      && home.config.systemd.user.services ? opencode-serve
    ) trusted;
    restricted-hosts-have-no-personal-state = lib.all (
      home:
      !home.config.homeSops.enable
      && !(home.config.home.file ? ".local/state/bash")
      && !(home.config.home.file ? ".local/share/scratchpads")
      && !(home.config.systemd.user.services ? state-autocommit)
      && !(home.config.systemd.user.services ? state-autopush)
      && !(home.config.systemd.user.services ? state-backup)
      && !(home.config.systemd.user.services ? notes-backup)
      && !(home.config.systemd.user.services ? github-backup)
      && !(home.config.systemd.user.services ? opencode-serve)
      && !(home.config.systemd.user.services ? sops-nix)
      && home.config.sops.secrets == { }
      && !(home.config.homeStorage.paths ? ".config/sops/age")
      && !(home.config.homeStorage.paths ? ".local/share/opencode")
      && !lib.hasInfix "sops-readonly" home.config.xdg.configFile."git/config".text
      && !lib.hasInfix "git_users" home.config.xdg.configFile."git/config".text
    ) restricted;
    restricted-history-remains-usable = lib.all (
      home:
      home.config.programs.bash.enable
      && home.config.programs.bash.historySize == -1
      && lib.hasInfix "XDG_RUNTIME_DIR" home.config.programs.bash.historyFile
      && lib.hasInfix "history -a; history -n" home.config.programs.bash.bashrcExtra
    ) restricted;
    branches-are-host-specific = lib.all (
      name: homes."emre@${name}".config.home.stateRepository.branch == "hosts/${name}"
    ) trustedNames;
    laptops-publish-notes = lib.all (
      name:
      let
        cfg = homes."emre@${name}".config;
      in
      cfg.systemd.user.services ? notes-backup
      && cfg.home.notesRepository.branch == "nocon"
      && cfg.home.notesRepository.remote == cfg.home.stateRepository.remote
      && cfg.home.file ? ".local/share/${cfg.home.notesRepository.directory}"
    ) laptopNames;
    headless-hosts-have-no-notes = lib.all (
      name:
      !(homes."emre@${name}".config.systemd.user.services ? notes-backup)
      && !(homes."emre@${name}".config.home.file ? ".local/share/scratchpads")
    ) headlessNames;
    backup-is-independent-of-activation = lib.all (
      home:
      !(home.config.home.activation ? checkStateRepository)
      && !(home.config.home.activation ? prepareStateRepository)
      && !(home.config.home.activation ? localStateHistory)
      && !(home.config.home.file ? ".local/state/bash")
      && home.config.systemd.user.services.state-backup.Service.Type == "oneshot"
      && home.config.systemd.user.timers.state-backup.Timer.OnStartupSec == "1min"
      && home.config.systemd.user.timers.state-backup.Timer.Persistent
    ) trusted;
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
pkgs.runCommand "home-ownership-policy" { failureNames = lib.concatStringsSep "," failures; } ''
  if [ -n "$failureNames" ]; then
    echo "failed home ownership checks: $failureNames" >&2
    exit 1
  fi
  touch "$out"
''
