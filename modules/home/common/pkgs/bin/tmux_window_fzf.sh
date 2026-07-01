#!/usr/bin/env bash

current_session=$(tmux display-message -p '#S')

window=$(tmux list-windows -t "$current_session" | fzf | awk '{print $1}' | sed 's/:.*//g')

tmux select-window -t "$current_session:$window"
