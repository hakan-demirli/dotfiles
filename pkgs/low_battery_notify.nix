{ pkgs, ... }:
let
  low_level = "25";
  critical_level = "5";

  low_battery_notify = pkgs.writers.writeBash "lowBatteryNotifier" ''
    set -u

    BAT_PCT=""
    BAT_STA=""
    for bat in /sys/class/power_supply/BAT*; do
        [ -d "$bat" ] || continue
        if [ -r "$bat/capacity" ] && [ -r "$bat/status" ]; then
            BAT_PCT=$(${pkgs.coreutils}/bin/cat "$bat/capacity" 2>/dev/null)
            BAT_STA=$(${pkgs.coreutils}/bin/cat "$bat/status" 2>/dev/null)
            break
        fi
    done

    [ -n "$BAT_PCT" ] || exit 0
    [ -n "$BAT_STA" ] || exit 0
    case "$BAT_PCT" in
        *[!0-9]*) exit 0 ;;
    esac

    if [ "$BAT_PCT" -le ${low_level} ] && [ "$BAT_PCT" -gt ${critical_level} ] && [ "$BAT_STA" = "Discharging" ]; then
        DISPLAY=:0.0 ${pkgs.dunst}/bin/dunstify \
            -a battery \
            -h string:x-dunst-stack-tag:battery \
            -u normal \
            -i battery-caution \
            "Low battery."
    fi

    if [ "$BAT_PCT" -le ${critical_level} ] && [ "$BAT_STA" = "Discharging" ]; then
        DISPLAY=:0.0 ${pkgs.dunst}/bin/dunstify \
            -a battery \
            -h string:x-dunst-stack-tag:battery \
            -u critical \
            -i battery-empty \
            "Charge me or watch me die!"
    fi
  '';
in
{
  systemd.user.services.low_battery_notify = {
    Unit.Description = "low battery notifier";
    Service.ExecStart = low_battery_notify;
  };

  systemd.user.timers.low_battery_notify = {
    Unit.Description = "low_battery_notify timer";
    Timer = {
      Unit = "low_battery_notify.service";
      OnCalendar = "*:0/2";
      Persistent = true;
      AccuracySec = "1s";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
