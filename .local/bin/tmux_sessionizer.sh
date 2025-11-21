#!/usr/bin/env bash

tmux list-sessions -F "#{session_name}|#{=15:session_name}: #{s|$HOME|~|:pane_current_path}" \
  | fzf -d '|' \
    --with-nth 2 \
    --preview 'tmux capture-pane -ep -t {1}' \
    --bind 'enter:execute(tmux switch-client -t {1})+accept'
