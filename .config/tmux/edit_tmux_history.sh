#!/usr/bin/env bash

file=`mktemp`.sh
tmux capture-pane -pS - > $file
tmux new-window -n:mywindow "nvim $file"
