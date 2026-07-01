{
  repoPath ? null,
  logBranch ? "nocon",
  commitOnCalendar ? "*:0/30",
  pushOnCalendar ? "*-*-* 00/2:00:00",
}:
{ config, pkgs, ... }:
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
    ];
    text = builtins.readFile ../bin/state-autopush.sh;
  };
in
{
  systemd.user = {
    services.state-autocommit = {
      Unit.Description = "Auto-commit changes in ${resolvedRepoPath}";
      Service = {
        Type = "oneshot";
        ExecStart = "${autocommit}/bin/state-autocommit.sh --repo-path ${resolvedRepoPath}";
      };
    };

    services.state-autopush = {
      Unit = {
        Description = "Auto-push ${logBranch} branch of ${resolvedRepoPath}";
        Wants = [ "network-online.target" ];
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${autopush}/bin/state-autopush.sh --repo-path ${resolvedRepoPath} --branch ${logBranch}";
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
}
