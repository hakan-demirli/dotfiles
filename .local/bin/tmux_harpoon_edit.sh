#!/usr/bin/env bash

tmux_cwd=$(pwd)
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

mkdir -p "$cache_dir"
touch "$data_file"

tmux display-popup -w 80% -E "hx $data_file"

# Remove empty lines from the data_file
sed -i '/^$/d' "$data_file"


