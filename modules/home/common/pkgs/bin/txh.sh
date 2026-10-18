#!/usr/bin/env bash
set -euo pipefail

tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
session_name=$(basename "$(pwd)" | tr '.:' '_')_$tmux_cwd_hash

if tmux has-session -t "$session_name" 2> /dev/null; then
  tmux attach-session -t "$session_name"
  exit 0
fi

tmux new-session -s "$session_name" "hx ."
