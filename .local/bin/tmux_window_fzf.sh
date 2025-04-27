#!/usr/bin/env bash

# Get the current session name
current_session=$(tmux display-message -p '#S')

# List windows in the current session for user to choose from
window=$(tmux list-windows -t "$current_session" | fzf | awk '{print $1}' | sed 's/:.*//g')

# Switch to the chosen window in the current session
tmux select-window -t "$current_session:$window"
