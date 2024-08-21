#!/usr/bin/env bash

idx=$1

tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.yaml"

hook_to_switch=$(sed -n "${idx}p" "$data_file")
if [[ -z "$hook_to_switch" ]]; then
  exit 0
fi

# Parse the hook_to_switch to get path, col, row, tmux_session, tmux_window
IFS=':, ' read -r path col row tmux_window tmux_session tmux_command tmux_pane_path <<< "$hook_to_switch"

# Check if editor_command is in tmux_command
tmux new-window -t "$tmux_session:$tmux_window"  2>/dev/null
echo "$path:$col:$row"

exit 0
