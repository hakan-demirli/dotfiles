#!/usr/bin/env bash

set -euo pipefail

fix_remote() {
  pkill gpg-agent 2> /dev/null || true
  rm -f "/run/user/$(id -u)/gnupg/S.gpg-agent"* 2> /dev/null || true

  sleep 0.5

  local current_tty
  current_tty=$(tty)
  export GPG_TTY="$current_tty"
  gpg-connect-agent updatestartuptty /bye > /dev/null 2>&1 || true

  if gpg-connect-agent 'scd serialno' /bye 2>&1 | grep -q "^D"; then
    echo "OK - YubiKey reachable"
  else
    echo "Tunnel dead - run 'fixgpg.sh kill' on laptop, reconnect SSH, then fixgpg.sh again"
  fi
}

kill_tunnel() {
  local host pids

  if ! command -v ssh-targets.sh > /dev/null 2>&1; then
    echo "ssh-targets.sh is not installed." >&2
    return 1
  fi

  host=$(ssh-targets.sh | fzf --height=40% --layout=reverse --border --prompt="Kill SSH for > ") || return 0

  if [[ -z $host ]]; then
    echo "No host selected."
    exit 1
  fi

  pids=$(pgrep -f "ssh.*$host" 2> /dev/null) || true

  if [[ -z $pids ]]; then
    echo "No SSH connections to $host found."
  else
    echo "Killing SSH connections to $host (PIDs: $pids)..."
    kill "$pids" 2> /dev/null || true
  fi

  echo ""
  echo "Now:"
  echo "  1. ssh $host"
  echo "  2. tmux attach"
  echo "  3. fixgpg.sh"
}

main() {
  case "${1:-}" in
    kill) kill_tunnel ;;
    *) fix_remote ;;
  esac
}

main "$@"
