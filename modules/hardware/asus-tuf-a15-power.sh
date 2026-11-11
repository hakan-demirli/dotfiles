#!/usr/bin/env bash
set -u
set -o pipefail

WMI=/sys/devices/platform/asus-nb-wmi
PLATFORM_PROFILE=/sys/firmware/acpi/platform_profile

write_to() {
  local path=$1 val=$2 actual
  [ -e "$path" ] || {
    echo "  FAIL $path: missing"
    return 1
  }
  if printf '%s\n' "$val" > "$path" 2> /dev/null; then
    actual=$(cat "$path" 2> /dev/null)
    if [ "$actual" = "$val" ]; then
      echo "  ok   $path = $val"
      return 0
    fi
    echo "  FAIL $path: wrote '$val' reads '$actual'"
  else
    echo "  FAIL $path: write rejected"
  fi
  return 1
}

read_fan_rpm() {
  local path rpm
  for path in "$WMI"/hwmon/hwmon*/fan1_input; do
    [ -r "$path" ] || continue
    IFS= read -r rpm < "$path" || continue
    case "$rpm" in
      "" | *[!0-9]*) continue ;;
    esac
    printf '%s\n' "$rpm"
    return 0
  done
  return 1
}

cmd_status() {
  echo "Fan boost mode       : $(cat "$WMI/fan_boost_mode" 2> /dev/null)"
  echo "Thermal policy       : $(cat "$WMI/throttle_thermal_policy" 2> /dev/null)"
  echo "Platform profile     : $(cat "$PLATFORM_PROFILE" 2> /dev/null)"
  echo "Fan rpm cpu          : $(read_fan_rpm || echo "?")"
}

apply() {
  local mode=$1 policy=$2 fail=0
  echo "==> $mode: fan_boost_mode=$policy throttle_thermal_policy=$policy"
  write_to "$WMI/fan_boost_mode" "$policy" || fail=1
  write_to "$WMI/throttle_thermal_policy" "$policy" || fail=1
  return "$fail"
}

cmd_apply() {
  case "${1:-}" in
    turbo) apply turbo 1 ;;
    balanced) apply balanced 0 ;;
    silent) apply silent 2 ;;
    *)
      echo "unknown mode: ${1:-}" >&2
      return 2
      ;;
  esac
}

cmd_help() {
  cat << 'EOF'
Board: ASUS TUF A15

  turbo                 fan_boost_mode=1 throttle_thermal_policy=1 (overboost)
  balanced              fan_boost_mode=0 throttle_thermal_policy=0 (default)
  silent                fan_boost_mode=2 throttle_thermal_policy=2 (silent)
EOF
}

case "${1:-}" in
  apply) cmd_apply "${2:-}" ;;
  status) cmd_status ;;
  rpm) read_fan_rpm ;;
  commands) ;;
  run)
    echo "unknown command: ${2:-}" >&2
    exit 2
    ;;
  help) cmd_help ;;
  *)
    echo "usage: ${0##*/} {apply MODE|status|rpm|commands|run COMMAND...|help}" >&2
    exit 2
    ;;
esac
