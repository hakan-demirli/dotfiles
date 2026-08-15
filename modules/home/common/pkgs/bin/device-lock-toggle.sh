#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-}
if [[ -z $MODE ]]; then
  echo "Usage: ${0##*/} {rotation|tablet} [toggle|on|off|status|swaync|true|false]" >&2
  exit 2
fi
shift

STATE_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

case "$MODE" in
  rotation)
    LOCK_FILE="$STATE_DIR/orientation_lock"
    WATCHER_PATTERN="orientation_watcher.py"
    NOTIFY_APP="rotation-lock"
    LOCKED_TITLE="Rotation locked"
    LOCKED_BODY="Screen will not auto-rotate"
    UNLOCKED_TITLE="Rotation unlocked"
    UNLOCKED_BODY="Auto-rotate restored"
    ;;
  tablet)
    LOCK_FILE="$STATE_DIR/tablet_mode_lock"
    WATCHER_PATTERN="tablet_mode_watcher.py"
    NOTIFY_APP="tablet-lock"
    LOCKED_TITLE="Tablet mode locked"
    LOCKED_BODY="Hinge events will be ignored"
    UNLOCKED_TITLE="Tablet mode unlocked"
    UNLOCKED_BODY="Hinge events will be honored again"
    ;;
  *)
    echo "Unknown lock mode: $MODE" >&2
    exit 2
    ;;
esac

notify() {
  command -v notify-send > /dev/null 2>&1 || return 0
  notify-send -a "$NOTIFY_APP" -t 2000 \
    -h "string:x-canonical-private-synchronous:$NOTIFY_APP" \
    "$1" "$2" 2> /dev/null || true
}

read_state() {
  local value
  value=$(cat "$LOCK_FILE" 2> /dev/null || true)
  [[ $value == 1 ]] && printf 'on\n' || printf 'off\n'
}

write_state() {
  mkdir -p "$STATE_DIR"
  printf '%s' "$1" > "$LOCK_FILE"
}

watcher_running() {
  pgrep -f "$WATCHER_PATTERN" > /dev/null 2>&1
}

lock_on() {
  if [[ $(read_state) == on ]]; then
    return 0
  fi
  write_state 1
  notify "$LOCKED_TITLE" "$LOCKED_BODY"
}

lock_off() {
  if [[ $(read_state) == off ]]; then
    return 0
  fi

  case "$MODE" in
    rotation)
      if watcher_running; then
        pkill -USR1 -f "$WATCHER_PATTERN" 2> /dev/null || true
      else
        write_state 0
      fi
      ;;
    tablet)
      write_state 0
      if watcher_running; then
        pkill -USR2 -f "$WATCHER_PATTERN" 2> /dev/null || true
      fi
      ;;
  esac

  notify "$UNLOCKED_TITLE" "$UNLOCKED_BODY"
}

toggle() {
  if [[ $(read_state) == on ]]; then
    lock_off
  else
    lock_on
  fi
}

status() {
  if [[ $(read_state) == on ]]; then
    printf 'true\n'
  else
    printf 'false\n'
  fi
}

from_toggle_state() {
  case "${SWAYNC_TOGGLE_STATE:-}" in
    true | TRUE | 1) lock_on ;;
    false | FALSE | 0) lock_off ;;
    *)
      printf 'SWAYNC_TOGGLE_STATE must be true or false, got [%s]\n' \
        "${SWAYNC_TOGGLE_STATE:-}" >&2
      return 2
      ;;
  esac
}

case "${1:-toggle}" in
  true | TRUE | 1) lock_on ;;
  false | FALSE | 0) lock_off ;;
  swaync) from_toggle_state ;;
  on | lock) lock_on ;;
  off | unlock) lock_off ;;
  status) status ;;
  toggle) toggle ;;
  *)
    printf 'Usage: %s [toggle|on|off|status|swaync|true|false]\n' "$0" >&2
    exit 2
    ;;
esac
