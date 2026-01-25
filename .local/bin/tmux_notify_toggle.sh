#!/usr/bin/env bash

set -u

STATE_DIR="/tmp/tmux_notify_locks"
mkdir -p "$STATE_DIR"

PANE_ID=""
SHELL_PID=""
SAFE_PANE_ID=""

send_telegram() {
  local msg="$1"
  if command -v tnotify.sh > /dev/null 2>&1; then
    tnotify.sh "$msg" &> /dev/null
  fi
}

send_desktop() {
  local msg="$1"
  if command -v notify-send > /dev/null 2>&1; then
    notify-send "Tmux Task Finished" "$msg"
  fi
}

send_sound() {
  if command -v ffplay > /dev/null 2>&1; then
    ffplay -autoexit -nodisp -af 'volume=2.0' "$HOME/.local/share/sounds/effects/nier_enter.mp3" > /dev/null 2>&1
  fi
}

toggle_channel() {
  local channel_name="$1"
  local lock_file="$2"
  local callback_func="$3"

  if [[ -f $lock_file ]]; then
    local watcher_pid
    watcher_pid=$(cat "$lock_file")

    if kill -0 "$watcher_pid" 2> /dev/null; then
      kill "$watcher_pid"
    fi
    rm "$lock_file"
    tmux display-message "[${channel_name^}] Notification cancelled."
    return
  fi

  local current_cmd_pid
  current_cmd_pid=$(pgrep -P "$SHELL_PID" -n)

  if [[ -z $current_cmd_pid ]]; then
    tmux display-message "No running command found."
    return 1
  fi

  local cmd_name
  cmd_name=$(ps -p "$current_cmd_pid" -o comm=)

  tmux display-message "[${channel_name^}] Attached to: $cmd_name"

  (
    while kill -0 "$current_cmd_pid" 2> /dev/null; do
      sleep 2
    done

    local msg
    msg="Task Finished on $(hostname)
Command: $cmd_name
Pane: $PANE_ID"

    "$callback_func" "$msg"

    rm -f "$lock_file"
  ) > /dev/null 2>&1 &
  disown

  echo $! > "$lock_file"
}

main() {
  local do_telegram=0
  local do_desktop=0
  local do_sound=0

  while getopts "tds" opt; do
    case $opt in
      t) do_telegram=1 ;;
      d) do_desktop=1 ;;
      s) do_sound=1 ;;
      *) exit 1 ;;
    esac
  done

  if ! PANE_ID=$(tmux display-message -p "#{pane_id}" 2> /dev/null); then
    echo "Error: Run inside tmux."
    exit 1
  fi
  SHELL_PID=$(tmux display-message -p "#{pane_pid}")
  SAFE_PANE_ID="${PANE_ID//%/_}"

  local lock_t="${STATE_DIR}/${SAFE_PANE_ID}_telegram.lock"
  local lock_d="${STATE_DIR}/${SAFE_PANE_ID}_desktop.lock"
  local lock_s="${STATE_DIR}/${SAFE_PANE_ID}_sound.lock"

  if [[ $do_telegram -eq 1 ]]; then
    toggle_channel "telegram" "$lock_t" "send_telegram"
  fi

  if [[ $do_desktop -eq 1 ]]; then
    toggle_channel "desktop" "$lock_d" "send_desktop"
  fi

  if [[ $do_sound -eq 1 ]]; then
    toggle_channel "sound" "$lock_s" "send_sound"
  fi

  if [[ $do_telegram -eq 0 && $do_desktop -eq 0 && $do_sound -eq 0 ]]; then
    tmux display-message "No flag provided (-t, -d, or -s)"
  fi
}

main "$@"
