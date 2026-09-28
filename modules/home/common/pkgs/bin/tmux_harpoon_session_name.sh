#!/usr/bin/env bash
set -euo pipefail

tmux_cwd=$1
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
data_file="$HOME/.cache/tmux_harpoon/$tmux_cwd_hash.csv"

if [[ -f $data_file ]]; then
  while IFS= read -r line; do
    if [[ $line == '# session_name: '* ]]; then
      name=${line#'# session_name: '}
      if [[ -n $name ]]; then
        printf '%s\n' "$name"
        exit 0
      fi
      break
    fi
  done < "$data_file"
fi

basename "$tmux_cwd"
