#!/usr/bin/env bash
set -euo pipefail

LOW=""
CRITICAL=""

usage() {
  cat << USAGE >&2
usage: $(basename "$0") --low PCT --critical PCT

  --low PCT       Integer threshold for a normal notification.
  --critical PCT  Integer threshold for a critical notification.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --low)
      LOW="$2"
      shift 2
      ;;
    --critical)
      CRITICAL="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "low-battery-notify: unexpected arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$LOW" ] || [ -z "$CRITICAL" ]; then
  echo "low-battery-notify: --low and --critical are both required" >&2
  usage
  exit 1
fi

case "$LOW" in
  '' | *[!0-9]*)
    echo "low-battery-notify: --low must be an integer, got '$LOW'" >&2
    exit 1
    ;;
esac
case "$CRITICAL" in
  '' | *[!0-9]*)
    echo "low-battery-notify: --critical must be an integer, got '$CRITICAL'" >&2
    exit 1
    ;;
esac

if ! command -v dunstify > /dev/null 2>&1; then
  echo "low-battery-notify: 'dunstify' not on PATH" >&2
  exit 2
fi
if ! command -v cat > /dev/null 2>&1; then
  echo "low-battery-notify: 'cat' not on PATH" >&2
  exit 2
fi

BAT_PCT=""
BAT_STA=""
for bat in /sys/class/power_supply/BAT*; do
  [ -d "$bat" ] || continue
  if [ -r "$bat/capacity" ] && [ -r "$bat/status" ]; then
    BAT_PCT=$(cat "$bat/capacity" 2> /dev/null)
    BAT_STA=$(cat "$bat/status" 2> /dev/null)
    break
  fi
done

if [ -z "$BAT_PCT" ] || [ -z "$BAT_STA" ]; then
  echo "low-battery-notify: no battery detected under /sys/class/power_supply/BAT* - no-op" >&2
  exit 0
fi

case "$BAT_PCT" in
  '' | *[!0-9]*)
    echo "low-battery-notify: unparseable capacity value '$BAT_PCT'" >&2
    exit 1
    ;;
esac

if [ "$BAT_PCT" -le "$CRITICAL" ] && [ "$BAT_STA" = "Discharging" ]; then
  DISPLAY=:0.0 dunstify \
    -a battery \
    -h string:x-dunst-stack-tag:battery \
    -u critical \
    -i battery-empty \
    "Charge me or watch me die!"
elif [ "$BAT_PCT" -le "$LOW" ] && [ "$BAT_STA" = "Discharging" ]; then
  DISPLAY=:0.0 dunstify \
    -a battery \
    -h string:x-dunst-stack-tag:battery \
    -u normal \
    -i battery-caution \
    "Low battery."
fi
