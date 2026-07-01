{
  user ? "hakan-demirli",
  cloneTo ? "$HOME/Desktop/infra/backup",
  tokenFile ? "$HOME/.config/secrets/github_token",
  excludeRegex ? "^(nix|nixpkgs)$",
  onCalendar ? "daily",
}:
{ pkgs, ... }:
{
  home.packages = [ pkgs.ghorg ];

  systemd.user.services.github-backup = {
    Unit.Description = "Mirror every ${user} GitHub repo (ghorg)";
    Service = {
      Type = "oneshot";
      Environment = [
        "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.bash
            pkgs.coreutils
            pkgs.git
            pkgs.ghorg
            pkgs.gnused
          ]
        }"
        "GHORG_SCM_TYPE=github"
        "GHORG_CLONE_TYPE=user"
        "GHORG_BASE_URL=https://api.github.com/"
        "GHORG_ABSOLUTE_PATH_TO_CLONE_TO=${cloneTo}"
        "GHORG_CLONE_WIKI=true"
        "GHORG_PRUNE=true"
        "GHORG_PRUNE_NO_CONFIRM=true"
        "GHORG_SKIP_ARCHIVED=false"
        "GHORG_SKIP_FORKS=true"
      ];
      ExecStart = pkgs.writeShellScript "github-backup-run" ''
        set -euo pipefail
        mkdir -p "$GHORG_ABSOLUTE_PATH_TO_CLONE_TO"

        if [[ ! -r "${tokenFile}" ]]; then
          echo "github-backup: token file ${tokenFile} not readable -- skipping" >&2
          exit 0
        fi

        export GHORG_GITHUB_TOKEN
        GHORG_GITHUB_TOKEN=$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "${tokenFile}" | head -1)

        if [[ -z "$GHORG_GITHUB_TOKEN" ]]; then
          echo "github-backup: ${tokenFile} is empty after stripping comments -- skipping" >&2
          exit 0
        fi

        ghorg clone "${user}" --exclude-match-regex '${excludeRegex}'
      '';
    };
  };

  systemd.user.timers.github-backup = {
    Unit.Description = "Timer: ghorg backup every ${onCalendar}";
    Timer = {
      OnCalendar = onCalendar;
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
