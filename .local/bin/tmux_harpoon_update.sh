#!/usr/bin/env bash

# editor_status=$1

tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

temp_file="$cache_dir/$tmux_cwd_hash.tmp"

read -r tmux_window_current tmux_command_current tmux_pane_path_current <<< "$(tmux display-message -p '#{window_index} #{pane_current_command} #{pane_current_path}')"

# echo "editor_status: $editor_status" >> test.dd

if [[ "$tmux_command_current" != "hx" ]]; then
    exit
fi




# Get helix information
status_line=$(tmux capture-pane -pS -3 | rg -e "(?:NOR\s+|NORMAL|INS\s+|INSERT|SEL\s+|SELECT)[\p{Braille}]*\s+(\S*)\s[^│]* (\d+):(\d+).*" -o --replace '$1 $2 $3')
read -r buffer_path cursor_row_current cursor_col_current <<< "$status_line"

# Get tmux information
read -r tmux_session tmux_window tmux_command tmux_pane_path <<< "$(tmux display-message -p '#{session_name} #{window_index} #{pane_current_command} #{pane_current_path}')"
tmux_window=${tmux_window//@/}

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

# If buffer_path is just a filename, prepend tmux_pane_path
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

    # Read original file, write to temp file, substituting the target line
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
