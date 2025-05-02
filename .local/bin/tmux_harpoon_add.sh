#!/usr/bin/env bash

tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.yaml"

# Get helix information
status_line=$(tmux capture-pane -pS -3 | rg -e "(?:NOR\s+|NORMAL|INS\s+|INSERT|SEL\s+|SELECT)[\p{Braille}]*\s+(\S*)\s[^│]* (\d+):(\d+).*" -o --replace '$1 $2 $3')
read -r buffer_path cursor_row cursor_col <<< "$status_line"

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


# Assign default values if buffer_path, cursor_row, and cursor_col are empty
: "${buffer_path:="default_path"}"
: "${cursor_row:="0"}"
: "${cursor_col:="0"}"

if [[ "$buffer_path" == ~* ]]; then
  buffer_path="${buffer_path/#\~/$HOME}"
fi

# If buffer_path is just a filename, prepend tmux_pane_path
if [[ "$buffer_path" != /* ]]; then
  buffer_path="$tmux_pane_path/$buffer_path"
else
  buffer_path=$(realpath "$buffer_path")
fi

populated=1
if [[ ! -f "$data_file" ]]; then
  populated=0
  mkdir -p "$cache_dir"
  touch "$data_file"
fi

if [[ "$buffer_path" != *"/default_path"* ]]; then
  # Check if the buffer_path already exists in the data_file
  if grep -q "^$buffer_path:" "$data_file"; then
    tmux_harpoon_update.sh
  else
    new_line="$buffer_path:$cursor_row:$cursor_col,$tmux_window,$tmux_session,$tmux_command,$tmux_pane_path"
    if [[ ! -s "$data_file" ]]; then
        # If the file is empty, append the new line
        echo "$new_line" >> "$data_file"
    else
        # If the file has content, prepend the new line
        sed -i "1i$new_line" "$data_file"
    fi
  fi
else
  new_line="$buffer_path:$cursor_row:$cursor_col,$tmux_window,$tmux_session,$tmux_command,$tmux_pane_path"
  if [[ ! -s "$data_file" ]]; then
      # If the file is empty, append the new line
      echo "$new_line" >> "$data_file"
  else
      # If the file has content, prepend the new line
      sed -i "1i$new_line" "$data_file"
  fi
fi

# Auto popullate the rest of it
if [[ "$populated" -eq 0 ]]; then
    default_entry_path="$tmux_pane_path/default_path"

    for i in {1..3}; do
        default_line="$default_entry_path:1:1,$i,$tmux_session,$tmux_command,$tmux_pane_path"
        echo "$default_line" >> "$data_file"
    done
fi

