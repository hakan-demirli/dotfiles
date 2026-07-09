#!/usr/bin/env bash

result=$(find -L . -type d | fzf)
if [[ -n $result ]]; then
  cd "$result" || exit 1
  tmux new-session 'code .'
fi
