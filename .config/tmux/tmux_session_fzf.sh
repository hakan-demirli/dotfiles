#!/usr/bin/env bash

session=$(tmux list-sessions | fzf | sed 's/: .*//g')
tmux switch-client -t "$session"
