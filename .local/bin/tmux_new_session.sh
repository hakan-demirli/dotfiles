#!/usr/bin/env bash
set -euo pipefail

file_manager="yazi"

if ! command -v $file_manager &> /dev/null; then
  echo "$file_manager could not be found"
  exit
fi

if [ $file_manager = "lf" ]; then
  target_dir=$(lf -print-last-dir)
elif [ $file_manager = "yazi" ]; then
  tmp="$(mktemp)"
  yazi --cwd-file="$tmp" "$@"
  target_dir=$(cat "$tmp")
fi

tmux_cwd_hash=$(echo -n "$target_dir" | md5sum | awk '{ print $1 }')
session_name=$(basename "$target_dir")_$tmux_cwd_hash

tmux new-session -d -s "$session_name" -c "$target_dir"
tmux switch-client -t "$session_name"
