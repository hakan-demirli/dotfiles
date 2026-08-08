{
  user ? "hakan-demirli",
  cloneTo ? null,
  excludeRegex ? "^(nix|nixpkgs)$",
  onCalendar ? "daily",
}:
{ config, pkgs, ... }:
let
  resolvedCloneTo =
    if cloneTo == null then "${config.home.homeDirectory}/Desktop/infra/backup" else cloneTo;
  secretEnvironmentFile = "${config.home.homeDirectory}/.config/secrets/environment";
  script = pkgs.writeShellApplication {
    name = "github-backup.sh";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.ghorg
    ];
    text = builtins.readFile ../bin/github-backup.sh;
  };
in
{
  home.packages = [ pkgs.ghorg ];

  systemd.user.services.github-backup = {
    Unit.Description = "Mirror every ${user} GitHub repo (ghorg)";
    Service = {
      Type = "oneshot";
      EnvironmentFile = secretEnvironmentFile;
      ExecStart = "${script}/bin/github-backup.sh --user ${user} --clone-to ${resolvedCloneTo} --exclude ${excludeRegex}";
    };
  };

  systemd.user.timers.github-backup = {
    Unit.Description = "Timer for github-backup";
    Timer = {
      OnCalendar = onCalendar;
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
