#!/usr/bin/env bash

WINDOW_NUM="$1"

tmux select-window -t "$WINDOW_NUM" 2> /dev/null
tmux new-window -t "$WINDOW_NUM" 2> /dev/null

exit 0
