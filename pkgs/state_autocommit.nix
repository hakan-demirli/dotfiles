# pkgs/state_autocommit.nix
{ pkgs, ... }:

let

  username = "emre";
  userHome = "/home/${username}";
  repoPath = "${userHome}/Desktop/state";
  logBranch = "nocon";

  scriptPath = pkgs.lib.makeBinPath [
    pkgs.bash
    pkgs.git
    pkgs.coreutils
    pkgs.gawk
    pkgs.openssh # For git commit signing and push
  ];

  autocommitScript = pkgs.writeShellScriptBin "state-autocommit" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

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

    echo "Pushing ${logBranch} branch..."
    git push origin ${logBranch}
    echo "State autopush successful."
  '';

in
{
  systemd.services = {
    state-autocommit = {
      description = "Automatically commit changes in the state directory";
      serviceConfig = {
        Type = "oneshot";
        User = username;
        Group = "users";
        WorkingDirectory = repoPath;
        # Set the full execution PATH and other necessary environment variables
        Environment = [
          "PATH=${scriptPath}"
          "HOME=${userHome}"
          "USER=${username}"
          "GIT_CONFIG_GLOBAL=${userHome}/.config/git/config"
        ];
        ExecStart = "${autocommitScript}/bin/state-autocommit";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    state-autopush = {
      description = "Automatically push the ${logBranch} branch";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = username;
        Group = "users";
        WorkingDirectory = repoPath;

        Environment = [
          "PATH=${scriptPath}"
          "HOME=${userHome}"
          "USER=${username}"
          "GIT_CONFIG_GLOBAL=${userHome}/.config/git/config"
        ];
        ExecStart = "${autopushScript}/bin/state-autopush";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };

  systemd.timers = {
    state-autocommit = {
      description = "Timer to auto-commit state directory changes every 30 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/30";
        Persistent = true;
      };
    };

    state-autopush = {
      description = "Timer to auto-push the ${logBranch} branch every 2 hours";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 00/2:00:00";
        Persistent = true;
      };
    };
  };
}
