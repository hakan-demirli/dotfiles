#!/usr/bin/env bash
tmux_harpoon_update.sh &

idx=$1
editor_command=${EDITOR:-hx}
terminal_command="bash"

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

# Check if editor_command is in tmux_command
if [[ "$tmux_command_target" == *"$editor_command"* ]]; then
  # check if window is still open in tmux
  if tmux has-session -t "$tmux_session_target:$tmux_window_target"; then
    # if window was open then just switch to it and send keys.
    tmux select-window -t "$tmux_session_target:$tmux_window_target" 2>/dev/null
    if [[ "$idx" == "1" ]]; then
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" M-u
    fi
    if [[ "$idx" == "2" ]]; then
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" M-i
    fi
    if [[ "$idx" == "3" ]]; then
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" M-o
    fi
    if [[ "$idx" == "4" ]]; then
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" M-p
    fi
  else
    # if not create a window, switch to it and open hx inside then send keys
    # shorten the path. tmux send-keys is slow
    relative_path=$(realpath --relative-to="$tmux_pane_path_target" "$buffer_dir_target/$buffer_name_target")
    tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2>/dev/null
    tmux send-keys -t "$tmux_session_target:$tmux_window_target" "hx $relative_path:$cursor_col_target:$cursor_row_target" C-m
  fi
else
  # check if window is still open in tmux
  if tmux has-session -t "$tmux_session_target:$tmux_window_target"; then
    # Check if terminal_command is in tmux_command
    if [[ "$tmux_command_target" == *"$terminal_command"* ]]; then
      tmux select-window -t "$tmux_session_target:$tmux_window_target"
    else
      # dont send keys if the window is open, just switch to it. 
      # tmux send-keys -t "$tmux_session:$tmux_window" "$tmux_command" C-m
      tmux select-window -t "$tmux_session_target:$tmux_window_target" 2>/dev/null
    fi
  else
    # Check if terminal_command is in tmux_command
    if [[ "$tmux_command_target" == *"$terminal_command"* ]]; then
      tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2>/dev/null
    else
      tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2>/dev/null
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" "$tmux_command_target" C-m
    fi
    tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2>/dev/null || tmux select-window -t "$tmux_session_target:$tmux_window_target"
  fi
fi

exit 0
