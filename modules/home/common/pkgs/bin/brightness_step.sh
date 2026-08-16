#!/usr/bin/env bash

set -euo pipefail

# The perceived step shrinks near the bottom of the curve, where a ten point
# jump is the difference between dim and off.
case "${1:-}" in
  up) sign="+" ;;
  down) sign="-" ;;
  *)
    printf 'usage: %s {up|down}\n' "${0##*/}" >&2
    exit 2
    ;;
esac

level="$(brightnessctl -m | cut -d, -f4)"
level="${level%\%}"

if [[ $level -le 5 ]]; then
  step=1
else
  step=10
fi

exec swayosd-client --min-brightness 0 --brightness "$sign$step"
