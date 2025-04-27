#!/usr/bin/env bash

function tmux_sessionizer () {
    selected_dir="$(find -L ~/Desktop /mnt/second/rep -maxdepth 1 \( \
        -name node_modules -o  \
        -name conda        -o  \
        -name env          -o  \
        -name bin          -o  \
        -name .direnv      -o  \
        -name .git         -o  \
        -name .github      -o  \
        -name __pycache__  -o  \
        -name venv         -o  \
        -name .venv            \
    \) -prune -o -type d -print | fzf)"

    if [[ -z "$selected_dir" ]]; then
        exit 0
    fi
    tmux_running=$(pgrep tmux)

    tmux_cwd_hash=$(echo -n "$selected_dir" | md5sum | awk '{ print $1 }')
    session_name=$(basename "$selected_dir")_$tmux_cwd_hash

    # # Log all variables to debug.log
    # echo "selected_dir: $selected_dir" >> debug.log
    # echo "tmux_running: $tmux_running" >> debug.log
    # echo "tmux_cwd_hash: $tmux_cwd_hash" >> debug.log
    # echo "session_name: $session_name" >> debug.log

    if [[ -z $TMUX ]] && [[ -z $tmux_running ]]; then
        tmux new-session -s "$session_name" -c "$selected_dir"
        exit 0
    fi

    if ! tmux has-session -t="$session_name" 2> /dev/null; then
        tmux new-session -ds "$session_name" -c "$selected_dir"
    fi

    tmux switch-client -t "$session_name"
}

tmux_sessionizer "$@"




