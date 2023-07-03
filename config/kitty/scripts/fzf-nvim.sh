#!/usr/bin/env bash

result=$(find -L * -type d | fzf)
if [[ -n "$result" ]]; then
    cd $result
    tmux new-session 'nvim .'
fi

