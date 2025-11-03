#!/usr/bin/env bash
set -euo pipefail

# $1: The CWD of the pane where the keybinding was triggered.

if [[ -z $1 ]]; then
  tmux display-message "Error: Script was called without the pane's current path."
  exit 1
fi
pane_cwd="$1"

input_path=$(xargs) # trim whitespace
if [[ -z $input_path ]]; then
  tmux display-message "input_path is empty from pipe"
  exit 0
fi

session_cwd=$(tmux display-message -p '#{session_path}')
session_cwd_hash=$(echo -n "$session_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$session_cwd_hash.csv"

if [[ ! -f $data_file ]]; then
  tmux display-message "Harpoon file not found for session starting in: $session_cwd"
  exit 1
fi

# The input path is relative to the pane's current directory.
if [[ $input_path == /* || $input_path == ~* ]]; then
  absolute_path=$(realpath -m -- "$input_path")
else
  absolute_path=$(realpath -m -- "$pane_cwd/$input_path")
fi

target_session=""
target_window=""
found_hook=0

while IFS= read -r line; do
  [[ $line =~ ^# || -z $line ]] && continue
  tmux_command_target=$(echo "$line" | cut -d, -f2)

  if [[ $tmux_command_target == "hx" ]]; then
    target_window=$(echo "$line" | cut -d, -f1)
    found_hook=1
    break
  fi
done < "$data_file"

if [[ $found_hook -eq 0 ]]; then
  tmux display-message "No 'hx' harpoon hook found for session: $session_cwd"
  tmux send-keys -t "{last}" "hx '${absolute_path}'" Enter
  exit 1
fi

session_line=$(grep '^# session_name:' "$data_file" || true)
target_session="${session_line#*: }"

if [[ -z $target_session ]]; then
  tmux display-message "Could not determine harpoon session name from data file."
  exit 1
fi

tmux select-window -t "$target_session:$target_window"

helix_command=":open '${absolute_path}'"
tmux send-keys -t "$target_session:$target_window" "$helix_command" Enter
