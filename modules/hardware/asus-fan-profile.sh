#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) -ne 0 ]]; then
  exec /run/wrappers/bin/sudo -- "$0" "$@"
fi

case "${1:-}" in
  turbo) value=1 ;;
  performance) value=0 ;;
  silent) value=2 ;;
  *)
    echo "Usage: ${0##*/} {turbo|performance|silent}" >&2
    exit 2
    ;;
esac

base=/sys/devices/platform/asus-nb-wmi
printf '%s\n' "$value" > "$base/fan_boost_mode"
printf '%s\n' "$value" > "$base/throttle_thermal_policy"
