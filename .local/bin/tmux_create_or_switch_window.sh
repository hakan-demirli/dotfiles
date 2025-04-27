#!/usr/bin/env bash

WINDOW_NUM="$1"

# Ignore errors by redirecting stderr to /dev/null
tmux select-window -t "$WINDOW_NUM" 2>/dev/null
tmux new-window -t "$WINDOW_NUM" 2>/dev/null

# Ensure the script always returns a success status
exit 0
