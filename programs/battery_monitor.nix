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
        + pkgs.writeScript "battery_status" ''
          #!${pkgs.stdenv.shell} --login
          . <(udevadm info -q property -p /sys/class/power_supply/BAT0 | grep -E 'POWER_SUPPLY_(CAPACITY|STATUS)=')
          if [[ $POWER_SUPPLY_STATUS = Discharging && $POWER_SUPPLY_CAPACITY -lt 15 ]];
          then notify-send -u critical "Battery is low: $POWER_SUPPLY_CAPACITY";
          fi
        '';
      Environment = ''"DISPLAY=:0"'';
    };
  };

  systemd.user.timers.battery_monitor = {
    Unit = {
      Description = "Timer: Send notification if battery is low";
      Requires = "battery_status.service";
    };

    Timer = {
      Unit = "battery_status.service";
      OnCalendar = "*:00/5";
    };

    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
