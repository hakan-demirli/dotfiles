#!/usr/bin/env bash
tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
_data_file="$cache_dir/$tmux_cwd_hash.json"
session_name=$(basename "$(pwd)")_$tmux_cwd_hash

if tmux has-session -t "$session_name" 2> /dev/null; then
  tmux switchc -t "$session_name"
  exit 0
else
  tmux new-session -d -s "$session_name"
  tmux switchc -t "$session_name"
fi
