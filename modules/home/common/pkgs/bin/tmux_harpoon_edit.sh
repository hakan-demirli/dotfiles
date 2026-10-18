#!/usr/bin/env bash

tmux_cwd=$(tmux display-message -p '#{session_path}')
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

tmux_harpoon_sync.sh

tmux display-popup -w 80% -E "hx $data_file"

tmux_harpoon_sync.sh
tmux refresh-client -S
