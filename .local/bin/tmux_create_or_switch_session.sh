#!/usr/bin/env bash
tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.json"
session_name=$(basename "$(pwd)")_$tmux_cwd_hash

# Check if the session exists
if tmux has-session -t "$session_name" 2>/dev/null; then
    # If the session exists, attach to it and exit the script
    tmux switchc -t "$session_name"
    exit 0
else
    tmux new-session -d -s "$session_name"
    tmux switchc -t "$session_name"
fi

