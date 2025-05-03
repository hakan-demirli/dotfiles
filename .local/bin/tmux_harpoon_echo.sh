#!/usr/bin/env bash

idx=$1

tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

hook_to_switch=$(sed -n "${idx}p" "$data_file")
if [[ -z "$hook_to_switch" ]]; then
  exit 0
fi

# Parse the hook_to_switch to get path, col, row, tmux_session, tmux_window
IFS=':,' read -r tmux_window_target tmux_command_target buffer_name_target cursor_row_target cursor_col_target buffer_dir_target tmux_pane_path_target <<<"$hook_to_switch"
tmux_session_line=$(tail -n 2 "$hook_to_switch" | head -n 1)
tmux_session_target="${tmux_session_line#*: }"

tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2>/dev/null

echo "$buffer_dir_target/$buffer_name_target:$cursor_col_target:$cursor_row_target"

exit 0
