#!/usr/bin/env bash

result=$(find * -type d | fzf)
if [[ -n "$result" ]]; then
    cd $result
    tmux new-session 'nvim .'
fi

