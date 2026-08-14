#!/usr/bin/env bash
set -euo pipefail

if ! command -v ssh-targets.sh > /dev/null 2>&1; then
  echo "ssh-targets.sh is not installed." >&2
  exit 1
fi

mapfile -t HOSTS < <(ssh-targets.sh)

if ((${#HOSTS[@]} == 0)); then
  echo "No hosts available."
  exit 1
fi

HOST=$(printf '%s\n' "${HOSTS[@]}" | fzf --height=40% --layout=reverse --border --prompt="Select Host > ") || exit 0

if [ -z "$HOST" ]; then
  echo "No host selected."
  exit 1
fi

read -r -p "Remote Path: " REMOTE_PATH

if [ -z "$REMOTE_PATH" ]; then
  echo "No path provided."
  exit 1
fi

BASENAME=$(basename "$REMOTE_PATH")
if [ -e "$BASENAME" ]; then
  echo "Error: Destination '$BASENAME' already exists locally. Aborting to prevent overwrite."
  exit 1
fi

echo "Connecting to $HOST..."

if ssh "$HOST" "command -v rsync >/dev/null 2>&1"; then
  echo "Using rsync..."
  rsync -avzP "$HOST":"$REMOTE_PATH" .
else
  echo "rsync not found, falling back to scp..."
  scp -r "$HOST":"$REMOTE_PATH" .
fi
