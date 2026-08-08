#!/usr/bin/env bash
set -euo pipefail

URL=""
SOUND=""

usage() {
  cat << USAGE >&2
usage: $(basename "$0") --url URL --sound PATH

  --url URL     ntfy subscription URL (base + comma-joined topics).
  --sound PATH  Absolute path to an audio file played on each event.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --url)
      URL="$2"
      shift 2
      ;;
    --sound)
      SOUND="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "ntfy-listener: unexpected arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$URL" ] || [ -z "$SOUND" ]; then
  echo "ntfy-listener: --url and --sound are both required" >&2
  usage
  exit 1
fi

for bin in ntfy ffplay notify-send; do
  if ! command -v "$bin" > /dev/null 2>&1; then
    echo "ntfy-listener: '$bin' not on PATH" >&2
    exit 2
  fi
done

exec ntfy sub -c /dev/null "$URL" \
  "bash -c 'ffplay -autoexit -nodisp -af volume=2.0 \"$SOUND\" >/dev/null 2>&1 & notify-send \"\$t\" \"\$m\"'"
