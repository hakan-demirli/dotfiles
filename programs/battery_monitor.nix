{pkgs, ...}: {
  systemd.user.services.battery_monitor = {
    Unit = {
      Description = "Service: Send notification if battery is low";
      After = "display-manager.service";
    };

    Service = {
      Type = "oneshot";
      ExecStart =
        ""
        + pkgs.writeScriptBin "battery_monitor" ''
          #!${pkgs.stdenv.shell} --login
          . <(${pkgs.eudev}/bin/udevadm info -q property -p /sys/class/power_supply/BAT0 | ${pkgs.gnugrep}/bin/grep -E 'POWER_SUPPLY_(CAPACITY|STATUS)=')
          if [[ $POWER_SUPPLY_STATUS = Discharging && $POWER_SUPPLY_CAPACITY -lt 25 ]];
          then ${pkgs.libnotify}/bin/notify-send -u critical "Battery is low: $POWER_SUPPLY_CAPACITY";
          fi
        '';
      Environment = ''"DISPLAY=:0"'';
    };
  };

  systemd.user.timers.battery_monitor = {
    Unit = {
      Description = "Timer: Send notification if battery is low";
      Requires = "battery_monitor.service";
    };

    Timer = {
      Unit = "battery_monitor.service";
      OnCalendar = "*:00/5";
    };

    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
