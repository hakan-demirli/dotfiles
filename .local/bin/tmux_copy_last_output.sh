#!/usr/bin/env bash

read -r -d '' pane_contents

output=$(printf "%s" "$pane_contents" | awk '
  /❯/ { i++; idx[i] = NR }
  { lines[NR] = $0 }
  END {
    if (i >= 2) {
      start = idx[i-1];
      end = idx[i] - 1;
      while (end >= start && lines[end] ~ /^[[:space:]]*$/) end--;
      if (end >= start) end--;
      for (j = start; j <= end; j++) print lines[j];
    }
  }
')

if [ -z "$output" ]; then
  exit 0
fi

if [[ -z "$SSH_CONNECTION" ]] && command -v wl-copy &>/dev/null; then
  printf "%s" "$output" | wl-copy
else
  tty=$(tmux display-message -p '#{client_tty}')
  printf "\e]52;c;%s\a" "$(printf "%s" "$output" | base64 --wrap=0)" > "$tty"
fi
