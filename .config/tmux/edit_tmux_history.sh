#!/usr/bin/env bash

file=$(mktemp).sh
tmux capture-pane -pS - > "$file"

id=5
while tmux list-windows -F '#{window_id}' | grep -q "^@$id"; do
  id=$((id+1))
done

tmux new-window -n:mywindow -t:$id "hx $file +9999999"
