#!/usr/bin/env bash

id=2
while tmux list-windows -F '#{window_id}' | grep -q "^@$id"; do
  id=$((id+1))
done

tmux new-window -n:mywindow -t:$id
