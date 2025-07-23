#!/usr/bin/env bash
set -euo pipefail

# open file path in first hx

input_path=$(xargs) # trim whitespace
[ -z "$input_path" ] \
&& tmux display-message "input_path is empty or wrong: $input_path" \
&& exit 0 # Exit if no path was selected

tmux_cwd=$(tmux display-message -p '#{session_path}')
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

if [[ "$input_path" == /* || "$input_path" == ~* ]]; then
  absolute_path=$(realpath -m -- "$input_path")
else
  absolute_path=$(realpath -m -- "$tmux_cwd/$input_path")
fi

if [[ ! -f "$data_file" ]]; then
  tmux display-message "Harpoon file not found for this directory: $tmux_cwd"
  exit 1
fi

target_session=""
target_window=""
found_hook=0

while IFS= read -r line; do
  [[ "$line" =~ ^# || -z "$line" ]] && continue

  tmux_command_target=$(echo "$line" | cut -d, -f2)

  if [[ "$tmux_command_target" == "hx" ]]; then
    target_window=$(echo "$line" | cut -d, -f1)
    found_hook=1
    break
  fi
done < "$data_file"

if [[ $found_hook -eq 0 ]]; then
  tmux display-message "No 'hx' harpoon hook found for this directory: $tmux_cwd and datafile: $data_file"
  # tmux send-keys "hx '${absolute_path}'" Enter
  exit 1
fi

session_line=$(grep '^# session_name:' "$data_file" || true)
target_session="${session_line#*: }"

if [[ -z "$target_session" ]]; then
    tmux display-message "Could not determine harpoon session name."
    exit 1
fi

tmux select-window -t "$target_session:$target_window"

helix_command=":o '${absolute_path}'"

tmux send-keys -t "$target_session:$target_window" "$helix_command" Enter
