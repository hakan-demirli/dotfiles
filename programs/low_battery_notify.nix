{pkgs, ...}: let
  low_level = "25";
  critical_level = "15";

  low_battery_notify = pkgs.writers.writeBash "lowBatteryNotifier" ''
    BAT_PCT=`${pkgs.acpi}/bin/acpi -b | ${pkgs.gnugrep}/bin/grep -P -o '[0-9]+(?=%)'`
    BAT_STA=`${pkgs.acpi}/bin/acpi -b | ${pkgs.gnugrep}/bin/grep -P -o '\w+(?=,)'`

    test $BAT_PCT -le ${low_level} && test $BAT_PCT -gt ${critical_level} && test $BAT_STA = "Discharging" \
        && DISPLAY=:0.0 ${pkgs.dunst}/bin/dunstify \
            -a battery \
            -h string:x-dunst-stack-tag:battery \
            -u normal \
            -i battery-caution \
            "Would be wise to keep the charger nearby."

    test $BAT_PCT -le ${critical_level} && test $BAT_STA = "Discharging" \
        && DISPLAY=:0.0 ${pkgs.dunst}/bin/dunstify \
            -a battery
            -h string:x-dunst-stack-tag:battery \
            -u critical \
            -i battery-empty \
            "Charge me or watch me die!"
  '';
in {
  systemd.user.services."low_battery_notify" = {
    Unit.Description = "low battery notifier";
    Service.ExecStart = low_battery_notify;
  };

  systemd.user.timers."low_battery_notify" = {
    Unit.Description = "low_battery_notify timer";
    Timer = {
      Unit = "low_battery_notify.service";
      OnCalendar = "*:0/2";
      Persistent = true;
      AccuracySec = "1s";
    };
    Install = {WantedBy = ["timers.target"];};
  };
}
