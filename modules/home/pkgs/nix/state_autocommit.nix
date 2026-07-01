{
  repoPath ? "$HOME/Desktop/infra/state",
  logBranch ? "nocon",
  commitOnCalendar ? "*:0/30",
  pushOnCalendar ? "*-*-* 00/2:00:00",
}:
{ pkgs, ... }:
let
  scriptPath = pkgs.lib.makeBinPath [
    pkgs.bash
    pkgs.git
    pkgs.coreutils
    pkgs.gawk
    pkgs.openssh
  ];

  autocommitScript = pkgs.writeShellScriptBin "state-autocommit" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    cd "${repoPath}" || { echo "state repo not present at ${repoPath}, skipping"; exit 0; }

    if [[ -z $(git status --porcelain) ]]; then
      echo "No changes in state directory. Exiting."
      exit 0
    fi

    git add .

    COMMIT_MSG="Auto-commit on $(date +'%Y-%m-%d %H:%M:%S')"
    CHANGED_FILES=$(git status --porcelain | awk '{print "  - "$2}')
    if [[ -n "$CHANGED_FILES" ]]; then
      COMMIT_MSG+=$'\n\nChanges:\n'"$CHANGED_FILES"
    fi

    git commit --no-gpg-sign -m "$COMMIT_MSG"

    echo "Successfully created a new state commit."
  '';

  autopushScript = pkgs.writeShellScriptBin "state-autopush" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    cd "${repoPath}" || { echo "state repo not present at ${repoPath}, skipping"; exit 0; }

    echo "Pushing ${logBranch} branch..."
    git push origin ${logBranch}
    echo "State autopush successful."
  '';
in
{
  systemd.user.services = {
    state-autocommit = {
      Unit.Description = "Auto-commit changes in the state directory";
      Service = {
        Type = "oneshot";
        Environment = [ "PATH=${scriptPath}" ];
        ExecStart = "${autocommitScript}/bin/state-autocommit";
      };
    };

    state-autopush = {
      Unit = {
        Description = "Auto-push the ${logBranch} branch";
        Wants = [ "network-online.target" ];
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        Environment = [ "PATH=${scriptPath}" ];
        ExecStart = "${autopushScript}/bin/state-autopush";
      };
    };
  };

  systemd.user.timers = {
    state-autocommit = {
      Unit.Description = "Timer: auto-commit state every 30 minutes";
      Timer = {
        OnCalendar = commitOnCalendar;
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    state-autopush = {
      Unit.Description = "Timer: auto-push state every 2 hours";
      Timer = {
        OnCalendar = pushOnCalendar;
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
