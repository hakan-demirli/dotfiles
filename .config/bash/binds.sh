#!/usr/bin/env bash

if [[ $- == *i* ]]; then
  bind -x '"\C-y": _copy_readline_to_clipboard'
fi
