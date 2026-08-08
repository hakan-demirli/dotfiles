#!/usr/bin/env bash

FILE_PATH=$(live-grep.sh | tr '\n' ' ' | sed 's/ *$//')

if [[ -n $FILE_PATH ]]; then
  tmux send-keys -t 0 ":open $FILE_PATH" C-m
fi
