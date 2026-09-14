{
  repoPath ? null,
  logBranch,
  remote,
  onCalendar ? "*:0/30",
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  resolvedRepoPath = if repoPath == null then "${config.xdg.dataHome}/state" else repoPath;
  historyFile = "${config.home.homeDirectory}/.local/state/bash/history";
  backup = pkgs.writeShellApplication {
    name = "state-backup";
    runtimeInputs = [
      pkgs.git
      pkgs.openssh
      pkgs.coreutils
      pkgs.util-linux
      config.homeSops.bootstrap
    ];
    text = builtins.readFile ../bin/state-backup.sh;
  };
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
    description = "The personal state checkout managed by the backup service.";
  };
  config = {
    home.stateRepository = {
      path = resolvedRepoPath;
      branch = logBranch;
      inherit remote;
    };
    systemd.user = {
      services.state-backup = {
        Unit = {
          Description = "Back up shell history to ${logBranch}";
          Wants = [ "sops-nix.service" ];
          After = [ "sops-nix.service" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${backup}/bin/state-backup ${lib.escapeShellArg resolvedRepoPath} ${lib.escapeShellArg logBranch} ${lib.escapeShellArg remote} ${lib.escapeShellArg historyFile}";
          TimeoutStartSec = 120;
        };
      };
      timers.state-backup = {
        Unit.Description = "Timer for state-backup";
        Timer = {
          OnStartupSec = "1min";
          OnCalendar = onCalendar;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
