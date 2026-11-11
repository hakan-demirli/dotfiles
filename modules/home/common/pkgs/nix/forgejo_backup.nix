{
  owner,
  forge,
  destination ? null,
  onCalendar ? "daily",
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  resolvedDestination =
    if destination == null then
      "${config.home.homeDirectory}/Desktop/infra/backup/forgejo"
    else
      destination;
  script = pkgs.writeShellApplication {
    name = "forgejo-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.git
      pkgs.gnused
      pkgs.jq
      pkgs.util-linux
      config.homeSops.bootstrap
    ];
    text = builtins.readFile ../bin/forgejo-backup.sh;
  };
in
{
  systemd.user.services.forgejo-backup = {
    Unit = {
      Description = "Back up every ${owner} Forgejo repository";
      Wants = [ "sops-nix.service" ];
      After = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${script}/bin/forgejo-backup ${lib.escapeShellArg forge} ${lib.escapeShellArg owner} ${lib.escapeShellArg resolvedDestination}";
    };
  };

  systemd.user.timers.forgejo-backup = {
    Unit.Description = "Timer for forgejo-backup";
    Timer = {
      OnCalendar = onCalendar;
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
