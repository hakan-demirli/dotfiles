{ pkgs, config, ... }:
let
  username = "emre";
  userHome = "/home/${username}";
in
{
  environment.systemPackages = [ pkgs.ghorg ];

  sops.secrets.git_token_emre_github = {
    owner = "emre";
  };

  systemd.services.github-backup = {
    description = "Backup all GitHub Repos";
    path = [
      pkgs.git
      pkgs.ghorg
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "emre";
      Environment = [
        "GHORG_SCM_TYPE=github"
        "GHORG_CLONE_TYPE=user"
        "GHORG_BASE_URL=https://api.github.com/"
        "GHORG_ABSOLUTE_PATH_TO_CLONE_TO=${userHome}/Desktop/backup"
        "GHORG_CLONE_WIKI=true"
        "GHORG_PRUNE=true"
        "GHORG_PRUNE_NO_CONFIRM=true"
        "GHORG_SKIP_ARCHIVED=false"
        "GHORG_SKIP_FORKS=true"
      ];
    };
    script = ''
      set -euo pipefail
      mkdir -p "$GHORG_ABSOLUTE_PATH_TO_CLONE_TO"

      # Securely load token into environment variable expected by ghorg
      export GHORG_GITHUB_TOKEN=$(cat ${config.sops.secrets.git_token_emre_github.path})

      # Run ghorg (most config is now in env vars)
      ghorg clone "hakan-demirli" \
        --exclude-match-regex '^(nix|nixpkgs)$'
    '';
  };

  systemd.timers.github-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
