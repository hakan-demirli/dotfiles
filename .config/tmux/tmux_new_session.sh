#!/usr/bin/env bash

target_dir=$(lf -print-last-dir)
session_name="$(basename "$target_dir")_$(echo -n "$target_dir" | md5sum | cut -d " " -f 1)"
tmux new-session -d -s "$session_name" -c "$target_dir"
tmux switch-client -t "$session_name"
