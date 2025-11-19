#!/usr/bin/env bash

if [[ -z $SSH_CONNECTION ]] && command -v wl-copy &> /dev/null; then
  if [[ $- == *i* ]]; then
    bind -x '"\C-y": _copy_readline_to_clipboard_local'
  fi
elif [[ -n $SSH_CONNECTION || -n $TMUX ]]; then
  if [[ $- == *i* ]]; then
    bind -x '"\C-y": _copy_readline_to_clipboard_remote'
  fi
fi
