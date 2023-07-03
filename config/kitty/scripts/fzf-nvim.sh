#!/usr/bin/env bash

result=$(find * -type d | fzf)
if [[ -n "$result" ]]; then
  nvim "$result"
fi

