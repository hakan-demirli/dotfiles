#!/usr/bin/env bash

# editor_status=$1

tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

temp_file="$cache_dir/$tmux_cwd_hash.tmp"

read -r tmux_window_current tmux_command_current tmux_pane_path_current <<< "$(tmux display-message -p '#{window_index} #{pane_current_command} #{pane_current_path}')"

# echo "editor_status: $editor_status" >> test.dd

status_line=$(tmux capture-pane -pS -3 | tail -n 3 | rg -e "(?:NOR\s+|NORMAL|INS\s+|INSERT|SEL\s+|SELECT)[\p{Braille}]*\s+(\S*)\s[^│]* (\d+):(\d+).*" -o --replace '$1 $2 $3')
read -r buffer_path cursor_row_current cursor_col_current <<< "$status_line"

read -r tmux_session tmux_window tmux_command tmux_pane_path <<< "$(tmux display-message -p '#{session_name} #{window_index} #{pane_current_command} #{pane_current_path}')"
tmux_window=${tmux_window//@/}

if [[ "$tmux_command_current" == "yazi" ]]; then
  if [[ -n "$status_line" ]]; then
    temp_full_path="$buffer_path"
    if [[ "$temp_full_path" == ~* ]]; then
      temp_full_path="${temp_full_path/#\~/$HOME}"
    fi
    if [[ "$temp_full_path" != /* ]]; then
      temp_full_path="$tmux_pane_path_current/$temp_full_path"
    fi

    temp_full_path=$(realpath "$temp_full_path" 2>/dev/null || echo "")

    if [[ -f "$temp_full_path" ]] && \
       [[ "$cursor_row_current" =~ ^[0-9]+$ ]] && \
       [[ "$cursor_col_current" =~ ^[0-9]+$ ]]; then
      tmux_command_current="hx"
    fi
  fi
fi

if [[ "$tmux_command_current" != "hx" ]]; then
    exit
fi

# # debug
# log_file="$cache_dir/$tmux_cwd_hash.log"
# {
#   echo "bpath: $buffer_path";
#   echo "col: $cursor_col";
#   echo "row: $cursor_row";
#   echo "win: $tmux_window";
#   echo "ses: $tmux_session";
#   echo "com: $tmux_command";
#   echo "ppath: $tmux_pane_path";
# } > "$log_file"


if [[ "$buffer_path" == ~* ]]; then
  buffer_path="${buffer_path/#\~/$HOME}"
fi

if [[ "$buffer_path" != /* ]]; then
  buffer_path="$tmux_pane_path/$buffer_path"
else
  buffer_path=$(realpath "$buffer_path")
fi

buffer_dir_current="$(dirname "$buffer_path")"
buffer_name_current="$(basename "$buffer_path")"






found_line_number=0
current_line_number=0
while IFS=':,' read -r tmux_window_e tmux_command_e buffer_name_e cursor_row_e cursor_col_e buffer_dir_e tmux_pane_path_e; do
    ((current_line_number++))

    if [[ "$tmux_window_e"  == "$tmux_window_current" && \
          "$tmux_command_e" == "$tmux_command_current" && \
          "$buffer_dir_e"   == "$buffer_dir_current"  && \
          "$buffer_name_e"  == "$buffer_name_current" ]]; then

        # echo "matched" >> test.dd
        found_line_number=$current_line_number
        break
    else
        # echo "fck" \
        #   "$tmux_window_e"  "vs" "$tmux_window_current"  \
        #   "$tmux_command_e" "vs" "$tmux_command_current"  \
        #   "$buffer_dir_e"   "vs" "$buffer_dir_current"   \
        #   "$buffer_name_e"  "vs" "$buffer_name_current" >> test.dd
        : 
    fi

done < "$data_file"

if [[ "$found_line_number" -gt 0 ]]; then
    new_line="${tmux_window_current},${tmux_command_current},${buffer_name_current}:${cursor_row_current}:${cursor_col_current},${buffer_dir_current},${tmux_pane_path_current}"

    current_line=0
    while IFS= read -r line; do
        ((current_line++))
        if [[ "$current_line" -eq "$found_line_number" ]]; then
            echo "$new_line"
        else
            echo "$line"
        fi
    done < "$data_file" > "$temp_file"

    mv "$temp_file" "$data_file"
fi
