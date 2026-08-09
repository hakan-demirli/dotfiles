#!/usr/bin/env bash

set -euo pipefail

readonly UNIT="screen-record.service"
readonly CLIPBOARD_UNIT="screen-record-clipboard.service"
readonly STATE_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/screen-record"
readonly LOCK_FILE="$STATE_DIR/lock"
readonly STATUS_FILE="$STATE_DIR/status"
readonly MODE_FILE="$STATE_DIR/mode"
readonly SELECTION_FILE="$STATE_DIR/selection"
readonly CAPTURE_FILE="$STATE_DIR/capture"
readonly STARTED_FILE="$STATE_DIR/started"

notify() {
  command -v notify-send > /dev/null 2>&1 || return 0
  notify-send -a screen-record -t 4000 \
    -h string:x-canonical-private-synchronous:screen-record \
    "$1" "${2:-}" 2> /dev/null || true
}

signal_waybar() {
  pkill -RTMIN+7 -x waybar 2> /dev/null || true
}

set_status() {
  mkdir -p "$STATE_DIR"
  printf '%s\n' "$1" > "$STATUS_FILE"
  signal_waybar
}

read_status() {
  local status="idle"
  if [[ -r $STATUS_FILE ]]; then
    IFS= read -r status < "$STATUS_FILE" || status="idle"
  fi
  printf '%s\n' "$status"
}

unit_busy() {
  local state
  state="$(systemctl --user is-active "$UNIT" 2> /dev/null || true)"
  [[ $state == "active" || $state == "activating" || $state == "deactivating" ]]
}

clear_state() {
  rm -f \
    "$STATUS_FILE" \
    "$MODE_FILE" \
    "$SELECTION_FILE" \
    "$CAPTURE_FILE" \
    "$STARTED_FILE"
}

output_directory() {
  printf '%s\n' "${SCREEN_RECORD_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}/Screencasts}"
}

focused_output() {
  if [[ -n ${WAYBAR_OUTPUT_NAME:-} ]]; then
    printf '%s\n' "$WAYBAR_OUTPUT_NAME"
    return 0
  fi

  command -v hyprctl > /dev/null 2>&1 || return 1
  hyprctl -j monitors 2> /dev/null \
    | jq -er 'map(select(.focused == true))[0].name // empty'
}

start_capture() {
  local mode="${1:-output}"
  local selection output_dir basename capture

  case "$mode" in
    output | region) ;;
    *)
      printf 'Unknown capture mode: %s\n' "$mode" >&2
      return 2
      ;;
  esac

  mkdir -p "$STATE_DIR"
  exec 9> "$LOCK_FILE"
  flock -x 9

  if unit_busy; then
    notify "Screen recording already active" "Click the recorder again to stop it"
    return 0
  fi

  clear_state

  if [[ $mode == "output" ]]; then
    selection="$(focused_output || true)"
  else
    set_status "selecting"
    if ! selection="$(slurp)"; then
      clear_state
      signal_waybar
      return 0
    fi

    if [[ -z $selection ]]; then
      clear_state
      signal_waybar
      return 0
    fi
  fi

  output_dir="$(output_directory)"
  mkdir -p "$output_dir"
  basename="screenrecord_$(date +%Y-%m-%d_%H-%M-%S-%N)"
  capture="$output_dir/$basename.mkv"

  printf '%s\n' "$mode" > "$MODE_FILE"
  printf '%s\n' "$selection" > "$SELECTION_FILE"
  printf '%s\n' "$capture" > "$CAPTURE_FILE"
  set_status "starting"

  systemctl --user reset-failed "$UNIT" > /dev/null 2>&1 || true
  if ! systemctl --user start --no-block "$UNIT"; then
    clear_state
    signal_waybar
    notify "Screen recording failed" "Could not start $UNIT"
    return 1
  fi
}

stop_capture() {
  mkdir -p "$STATE_DIR"
  exec 9> "$LOCK_FILE"
  flock -x 9

  if unit_busy || [[ $(read_status) == "starting" ]]; then
    set_status "stopping"
    systemctl --user stop --no-block "$UNIT"
  else
    clear_state
    signal_waybar
  fi
}

toggle_capture() {
  if unit_busy || [[ $(read_status) == "starting" ]]; then
    stop_capture
  else
    start_capture "${1:-output}"
  fi
}

default_audio_source() {
  local sink source _id name _rest

  if [[ -n ${SCREEN_RECORD_AUDIO_SOURCE:-} ]]; then
    printf '%s\n' "$SCREEN_RECORD_AUDIO_SOURCE"
    return 0
  fi

  command -v pactl > /dev/null 2>&1 || return 1
  sink="$(pactl get-default-sink 2> /dev/null || true)"
  [[ -n $sink ]] || return 1
  source="$sink.monitor"

  while read -r _id name _rest; do
    if [[ $name == "$source" ]]; then
      printf '%s\n' "$source"
      return 0
    fi
  done < <(pactl list short sources 2> /dev/null)

  return 1
}

run_capture() {
  local mode selection capture audio_source
  local -a args

  if [[ ! -r $MODE_FILE || ! -r $SELECTION_FILE || ! -r $CAPTURE_FILE ]]; then
    printf 'Screen recording request is incomplete in %s\n' "$STATE_DIR" >&2
    return 1
  fi

  IFS= read -r mode < "$MODE_FILE"
  IFS= read -r selection < "$SELECTION_FILE"
  IFS= read -r capture < "$CAPTURE_FILE"
  audio_source="$(default_audio_source || true)"

  args=(
    --filename "$capture"
    --codec avc
    --bitrate "500 KB"
    --audio
    --audio-codec aac
    --audio-bitrate "16 KB"
  )
  if [[ -n $audio_source ]]; then
    args+=(--audio-device "$audio_source")
  fi

  case "$mode" in
    output)
      if [[ -n $selection ]]; then
        args+=(--output "$selection")
      fi
      ;;
    region) args+=(--geometry "$selection") ;;
    *)
      printf 'Invalid capture mode in request: %s\n' "$mode" >&2
      return 1
      ;;
  esac

  date +%s > "$STARTED_FILE"
  set_status "recording"
  exec wl-screenrec "${args[@]}"
}

copy_output_uri() {
  local output="$1"
  local uri wl_copy

  uri="$(jq -rn --arg path "$output" '"file://" + ($path | split("/") | map(@uri) | join("/"))')"
  wl_copy="$(command -v wl-copy)"
  systemctl --user stop "$CLIPBOARD_UNIT" > /dev/null 2>&1 || true
  systemctl --user reset-failed "$CLIPBOARD_UNIT" > /dev/null 2>&1 || true
  systemd-run --user --quiet --collect --unit="${CLIPBOARD_UNIT%.service}" \
    "$wl_copy" --foreground --type text/uri-list "$uri" > /dev/null
}

finish_capture() {
  local capture=""
  local result="${SERVICE_RESULT:-unknown}"
  local copied="false"

  if [[ -r $CAPTURE_FILE ]]; then
    IFS= read -r capture < "$CAPTURE_FILE" || capture=""
  fi

  if [[ $result == "success" && -n $capture && -s $capture ]]; then
    set_status "copying"
    if copy_output_uri "$capture"; then
      copied="true"
    fi

    if [[ $copied == "true" ]]; then
      notify "Screen recording saved" "$capture"$'\n'"Copied to clipboard"
    else
      notify "Screen recording saved" "$capture"$'\n'"Clipboard copy failed"
    fi
  else
    notify "Screen recording failed" \
      "Result: $result. Partial MKV kept at $capture. Check journalctl --user -u $UNIT"
  fi

  clear_state
  signal_waybar
}

format_duration() {
  local elapsed="$1"
  if ((elapsed >= 3600)); then
    printf '%02d:%02d:%02d' "$((elapsed / 3600))" "$(((elapsed / 60) % 60))" "$((elapsed % 60))"
  else
    printf '%02d:%02d' "$((elapsed / 60))" "$((elapsed % 60))"
  fi
}

waybar_status() {
  local status started now elapsed duration capture tooltip text class
  status="$(read_status)"

  case "$status" in
    selecting)
      text="SELECT"
      tooltip="Select a recording region; Escape cancels"
      class="selecting"
      ;;
    starting)
      text="START"
      tooltip="Starting screen recording"
      class="starting"
      ;;
    recording)
      started=0
      if [[ -r $STARTED_FILE ]]; then
        IFS= read -r started < "$STARTED_FILE" || started=0
      fi
      now="$(date +%s)"
      if [[ $started =~ ^[0-9]+$ ]] && ((now >= started)); then
        elapsed="$((now - started))"
      else
        elapsed=0
      fi
      duration="$(format_duration "$elapsed")"
      capture=""
      if [[ -r $CAPTURE_FILE ]]; then
        IFS= read -r capture < "$CAPTURE_FILE" || capture=""
      fi
      text=$'REC\n'"$duration"
      tooltip="Recording $capture with system audio"$'\n'"Click to stop"
      class="recording"
      ;;
    stopping)
      text="STOP"
      tooltip="Finalizing screen recording"
      class="stopping"
      ;;
    copying)
      text="SAVE"
      tooltip="Copying screen recording to the clipboard"
      class="copying"
      ;;
    *)
      text=$'\uf03d'
      tooltip=$'Screen recording with system audio\nLeft click: record this output\nRight click: select region'
      class="idle"
      ;;
  esac

  jq -cn \
    --arg text "$text" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{text: $text, tooltip: $tooltip, class: $class, alt: $class}'
}

case "${1:-toggle}" in
  start)
    start_capture "${2:-output}"
    ;;
  stop)
    stop_capture
    ;;
  toggle)
    toggle_capture "${2:-output}"
    ;;
  run)
    run_capture
    ;;
  finish)
    finish_capture
    ;;
  waybar | status)
    waybar_status
    ;;
  *)
    printf 'Usage: %s [start|stop|toggle] [output|region]\n' "$0" >&2
    printf '       %s [waybar|status]\n' "$0" >&2
    exit 2
    ;;
esac
