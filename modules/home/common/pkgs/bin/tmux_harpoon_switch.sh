#!/usr/bin/env bash
set -euo pipefail

idx=$1
key=$2
editor_command=${EDITOR:-hx}
terminal_command="bash"

tmux_cwd=$(tmux display-message -p '#{session_path}')
tmux_session_id=$(tmux display-message -p '#{session_id}')
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

if [[ ! -s $data_file ]]; then
  tmux_harpoon_sync.sh
fi

tmux_harpoon_update.sh &

hook_to_switch=$(sed -n "${idx}p" "$data_file")
if [[ -z $hook_to_switch ]] || [[ $hook_to_switch == '#'* ]]; then
  exit 0
fi

IFS=':,' read -r tmux_window_target tmux_command_target buffer_name_target cursor_row_target cursor_col_target buffer_dir_target tmux_pane_path_target <<< "$hook_to_switch"

if [[ -n $tmux_window_target ]] && tmux has-session -t "$tmux_session_id:$tmux_window_target" 2> /dev/null; then
  tmux select-window -t "$tmux_session_id:$tmux_window_target"
  if [[ $tmux_command_target == *"$editor_command"* ]]; then
    tmux send-keys -t "$tmux_session_id:$tmux_window_target" "$key"
  fi
  exit 0
fi

tmux_window_target=$(tmux new-window -t "$tmux_session_id:" -c "$tmux_pane_path_target" -P -F '#{window_id}')

if [[ $tmux_command_target == *"$editor_command"* ]]; then
  relative_path=$(realpath --relative-to="$tmux_pane_path_target" "$buffer_dir_target/$buffer_name_target")
  tmux send-keys -t "$tmux_session_id:$tmux_window_target" "hx $relative_path:$cursor_row_target:$cursor_col_target" C-m
elif [[ $tmux_command_target != *"$terminal_command"* ]]; then
  tmux send-keys -t "$tmux_session_id:$tmux_window_target" "$tmux_command_target" C-m
fi

tmux_harpoon_sync.sh "$idx" "$tmux_window_target"
