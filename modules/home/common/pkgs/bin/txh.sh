#!/usr/bin/env bash
set -euo pipefail

tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.yaml"
session_name=$(basename "$(pwd)" | tr '.:' '_')_$tmux_cwd_hash

if tmux has-session -t "$session_name" 2> /dev/null; then
  tmux attach-session -t "$session_name"
  exit 0
fi

if [[ ! -f $data_file ]]; then
  tmux new-session -s "$session_name" "hx ."
  exit 0
fi

min=9999
max=9999999

random_number=$((RANDOM % (max - min + 1) + min))
sed -i "s/,0,/,$random_number,/g" "$data_file"

first_hook=$(sed -n "1p" "$data_file")
first_window_id=$(echo "$first_hook" | awk -F',' '{ print $2 }')
sed -i "s/,$first_window_id,/,0,/g" "$data_file"

tmux new-session -s "$session_name" "hx ."
