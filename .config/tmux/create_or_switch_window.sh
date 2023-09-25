#!/usr/bin/env bash

WINDOW_NUM="$1"

# Check if the window exists
if ! tmux list-windows -F '#I' | grep -q "^$WINDOW_NUM$"; then
    # If it doesn't exist, create a new window
    tmux new-window -n "Alt-$WINDOW_NUM"
fi

# Switch to the specified window
tmux select-window -t "$WINDOW_NUM"
tmux select-pane -t 0
