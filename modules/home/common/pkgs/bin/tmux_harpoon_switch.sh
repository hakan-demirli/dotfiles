#!/usr/bin/env bash
set -euo pipefail

idx=$1
editor_command=${EDITOR:-nvim}
editor_name=$(basename "${editor_command%% *}")
terminal_command="bash"

tmux_cwd=$(tmux display-message -p '#{session_path}')
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

if [[ ! -f $data_file ]] || [[ ! -s $data_file ]]; then
  IFS='|' read -r tmux_session tmux_pane_path <<< "$(tmux display-message -p '#{session_name}|#{pane_current_path}')"
  mkdir -p "$cache_dir"
  {
    for i in {0..3}; do
      echo "$i,bash,::,,$tmux_pane_path"
    done
    echo
    echo "# session_name: $tmux_session"
    echo "# pane_id , command , file_name:r:c , file_path , workspace_dir"
  } > "$data_file"
fi

tmux_harpoon_update.sh &

hook_to_switch=$(sed -n "${idx}p" "$data_file")
if [[ -z $hook_to_switch ]]; then
  exit 0
fi

IFS=':,' read -r tmux_window_target tmux_command_target buffer_name_target cursor_row_target cursor_col_target buffer_dir_target tmux_pane_path_target <<< "$hook_to_switch"
tmux_session_line=$(tail -n 2 "$data_file" | head -n 1)
tmux_session_target="${tmux_session_line#*: }"

if [[ $tmux_command_target == "nvim" || $tmux_command_target == "$editor_name" || $tmux_command_target == "hx" ]]; then
  target_path="$buffer_dir_target/$buffer_name_target"
  cursor_row_target=${cursor_row_target:-1}
  cursor_col_target=${cursor_col_target:-1}

  if tmux has-session -t "$tmux_session_target:$tmux_window_target"; then
    tmux select-window -t "$tmux_session_target:$tmux_window_target" 2> /dev/null
    active_command=$(tmux display-message -p -t "$tmux_session_target:$tmux_window_target" '#{pane_current_command}')

    if [[ $active_command == "nvim" ]]; then
      nvim_path=${target_path//\'/\'\'}
      printf -v editor_open ":execute 'edit ' . fnameescape('%s') | call cursor(%s, %s)" "$nvim_path" "$cursor_row_target" "$cursor_col_target"
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" Escape "$editor_open" C-m
    elif [[ $active_command == "hx" ]]; then
      case "$idx" in
        1) editor_key=M-u ;;
        2) editor_key=M-i ;;
        3) editor_key=M-o ;;
        4) editor_key=M-p ;;
      esac
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" "$editor_key"
    else
      printf -v editor_launch 'nvim "+call cursor(%s, %s)" -- %q' "$cursor_row_target" "$cursor_col_target" "$target_path"
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" "$editor_launch" C-m
    fi
  else
    relative_path=$(realpath --relative-to="$tmux_pane_path_target" "$target_path")
    printf -v editor_launch 'nvim "+call cursor(%s, %s)" -- %q' "$cursor_row_target" "$cursor_col_target" "$relative_path"
    tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2> /dev/null
    tmux send-keys -t "$tmux_session_target:$tmux_window_target" "$editor_launch" C-m
  fi
else
  if tmux has-session -t "$tmux_session_target:$tmux_window_target"; then
    if [[ $tmux_command_target == *"$terminal_command"* ]]; then
      tmux select-window -t "$tmux_session_target:$tmux_window_target"
    else
      tmux select-window -t "$tmux_session_target:$tmux_window_target" 2> /dev/null
    fi
  else
    if [[ $tmux_command_target == *"$terminal_command"* ]]; then
      tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2> /dev/null
    else
      tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2> /dev/null
      tmux send-keys -t "$tmux_session_target:$tmux_window_target" "$tmux_command_target" C-m
    fi
    tmux new-window -t "$tmux_session_target:$tmux_window_target" -c "$tmux_pane_path_target" 2> /dev/null || tmux select-window -t "$tmux_session_target:$tmux_window_target"
  fi
fi

exit 0
