#!/usr/bin/env bash

TARGET_DIR="$HOME"
USERNAME="$(whoami)"

SESSION_NAME="${USERNAME}_$(echo -n "$TARGET_DIR" | md5sum | cut -d' ' -f1)"

if [ -n "$TMUX" ]; then
  if ! tmux has-session -t="$SESSION_NAME" 2> /dev/null; then
    tmux new-session -ds "$SESSION_NAME" -c "$TARGET_DIR"
  fi
  tmux switch-client -t "$SESSION_NAME"
else
  if ! tmux info &> /dev/null; then
    tmux new-session -ds "$SESSION_NAME" -c "$TARGET_DIR"
  else
    if ! tmux has-session -t="$SESSION_NAME" 2> /dev/null; then
      tmux new-session -ds "$SESSION_NAME" -c "$TARGET_DIR"
    fi
  fi
  exec tmux attach-session -t "$SESSION_NAME"
fi
