#!/usr/bin/env bash

set -u

STATE_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
STATE_FILE="$STATE_DIR/tablet_mode"

log() { printf '[tablet_mode_apply.sh] %s\n' "$*" >&2; }

notify() {
  command -v notify-send > /dev/null 2>&1 || return 0
  notify-send -a tablet-mode -t 2500 \
    -h string:x-canonical-private-synchronous:tablet-mode \
    "$1" "${2:-}" 2> /dev/null || true
}

hide_keyboard() {
  command -v qs > /dev/null 2>&1 || return 0
  qs ipc --any-display call osk close > /dev/null 2>&1 || true
}

apply_on() {
  log "entering tablet mode"
  echo on > "$STATE_FILE"
  notify "Tablet mode" "On"
}

apply_off() {
  log "leaving tablet mode"
  hide_keyboard
  echo off > "$STATE_FILE"
  notify "Laptop mode" "On"
}

case "${1:-}" in
  on) apply_on ;;
  off) apply_off ;;
  toggle)
    if [[ "$(cat "$STATE_FILE" 2> /dev/null)" == "on" ]]; then
      apply_off
    else
      apply_on
    fi
    ;;
  status)
    cat "$STATE_FILE" 2> /dev/null || echo "off"
    ;;
  *)
    echo "usage: $0 {on|off|toggle|status}" >&2
    exit 2
    ;;
esac
