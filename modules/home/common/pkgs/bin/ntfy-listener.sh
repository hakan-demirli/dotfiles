#!/usr/bin/env bash
set -euo pipefail

URL=""
SOURCES=""
SOUND=""

usage() {
  cat << USAGE >&2
usage: $(basename "$0") --url URL --sources FILE --sound PATH

  --url URL       ntfy subscription URL (base + comma-joined topics).
  --sources FILE  JSON object that maps each topic to the application name of its notifications.
  --sound PATH    Absolute path to an audio file for notifications that need attention.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --url)
      URL="$2"
      shift 2
      ;;
    --sources)
      SOURCES="$2"
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

if [ -z "$URL" ] || [ -z "$SOURCES" ] || [ -z "$SOUND" ]; then
  echo "ntfy-listener: --url, --sources and --sound are all required" >&2
  usage
  exit 1
fi

for bin in ntfy jq notify-send; do
  if ! command -v "$bin" > /dev/null 2>&1; then
    echo "ntfy-listener: '$bin' not on PATH" >&2
    exit 2
  fi
done

SOURCES_JSON="$(jq -ce '
  if type == "object" and length > 0 and all(.[]; type == "string" and length > 0)
  then .
  else error("sources must map each topic to a non-empty application name")
  end
' "$SOURCES")"

readonly FIELDS=7

parse() {
  jq --raw-output0 --argjson sources "$SOURCES_JSON" '
    select(.event == "message")
    | ($sources[.topic] // error("unknown topic \(.topic)")) as $app
    | (.title // "") as $title
    | (.message // "") as $message
    | (.priority // 3) as $priority
    | [
        $app,
        (if $title != "" then $title elif $message != "" then $message else $app end),
        (if $title != "" then $message else "" end),
        (if $priority >= 5 then "critical" elif $priority <= 2 then "low" else "normal" end),
        (if $priority <= 2 then "passive" elif $priority == 3 then "active" else "time-sensitive" end),
        (.sequence_id // ""),
        (.click // "")
      ]
    | .[]
  ' <<< "$1"
}

forward() {
  local fields=()
  mapfile -d '' -t fields < <(parse "$1" 2> /dev/null || true)
  if [ "${#fields[@]}" -ne "$FIELDS" ]; then
    echo "ntfy-listener: skipped an event that is not a message from a known topic" >&2
    return 0
  fi

  local args=(
    "--app-name=${fields[0]}"
    "--urgency=${fields[3]}"
    "--hint=string:x-interruption-level:${fields[4]}"
    "--hint=string:sound-file:$SOUND"
  )
  if [ -n "${fields[5]}" ]; then
    args+=("--hint=string:x-dunst-stack-tag:${fields[5]}")
  fi
  if [ -n "${fields[6]}" ]; then
    args+=("--hint=string:x-default-url:${fields[6]}")
  fi

  if ! notify-send "${args[@]}" -- "${fields[1]}" "${fields[2]}"; then
    echo "ntfy-listener: notify-send failed for '${fields[1]}'" >&2
  fi
}

ntfy sub -c /dev/null "$URL" | while IFS= read -r event; do
  forward "$event"
done
