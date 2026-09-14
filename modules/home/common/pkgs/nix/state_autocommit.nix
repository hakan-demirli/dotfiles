{
  repoPath ? null,
  logBranch,
  remote,
  commitOnCalendar ? "*:0/30",
  pushOnCalendar ? "*-*-* 00/2:00:00",
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  resolvedRepoPath =
    if repoPath == null then "${config.home.homeDirectory}/Desktop/infra/state" else repoPath;
  autocommit = pkgs.writeShellApplication {
    name = "state-autocommit.sh";
    runtimeInputs = [
      pkgs.bash
      pkgs.git
      pkgs.coreutils
      pkgs.gawk
      pkgs.openssh
      pkgs.util-linux
    ];
    text = builtins.readFile ../bin/state-autocommit.sh;
  };

  autopush = pkgs.writeShellApplication {
    name = "state-autopush.sh";
    runtimeInputs = [
      pkgs.bash
      pkgs.git
      pkgs.coreutils
      pkgs.openssh
      pkgs.util-linux
    ];
    text = builtins.readFile ../bin/state-autopush.sh;
  };
  commitCommand = "${autocommit}/bin/state-autocommit.sh --repo-path ${lib.escapeShellArg resolvedRepoPath} --branch ${lib.escapeShellArg logBranch}";
in
{
  options.home.stateRepository = lib.mkOption {
    type = lib.types.submodule {
      options = {
        path = lib.mkOption { type = lib.types.str; };
        branch = lib.mkOption { type = lib.types.str; };
        remote = lib.mkOption { type = lib.types.str; };
      };
    };
    readOnly = true;
    internal = true;
    description = "The personal state checkout prepared during user provisioning.";
  };
  config = {
    home = {
      stateRepository = {
        path = resolvedRepoPath;
        branch = logBranch;
        inherit remote;
      };
      file.".local/state/bash".source =
        config.lib.file.mkOutOfStoreSymlink "${resolvedRepoPath}/.local/state/bash";
      activation.checkStateRepository = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        run ${commitCommand} --check
      '';
    };
    systemd.user = {
      services.state-autocommit = {
        Unit.Description = "Auto-commit changes in ${resolvedRepoPath}";
        Service = {
          Type = "oneshot";
          ExecStart = commitCommand;
        };
      };

      services.state-autopush = {
        Unit = {
          Description = "Auto-push ${logBranch} branch of ${resolvedRepoPath}";
          StartLimitIntervalSec = 900;
          StartLimitBurst = 6;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${autopush}/bin/state-autopush.sh --repo-path ${lib.escapeShellArg resolvedRepoPath} --branch ${lib.escapeShellArg logBranch}";
          Restart = "on-failure";
          RestartSec = 30;
        };
      };

      timers.state-autocommit = {
        Unit.Description = "Timer for state-autocommit";
        Timer = {
          OnCalendar = commitOnCalendar;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      timers.state-autopush = {
        Unit.Description = "Timer for state-autopush";
        Timer = {
          OnCalendar = pushOnCalendar;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
