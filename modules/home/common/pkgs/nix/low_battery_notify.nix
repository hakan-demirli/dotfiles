{ pkgs, ... }:
let
  script = pkgs.writeShellApplication {
    name = "low-battery-notify.sh";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dunst
    ];
    text = builtins.readFile ../bin/low-battery-notify.sh;
  };
in
{
  systemd.user.services.low-battery-notify = {
    Unit.Description = "low battery notifier";
    Service.ExecStart = "${script}/bin/low-battery-notify.sh --low 25 --critical 5";
  };

  systemd.user.timers.low-battery-notify = {
    Unit.Description = "Timer for low-battery-notify";
    Timer = {
      Unit = "low-battery-notify.service";
      OnCalendar = "*:0/2";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
