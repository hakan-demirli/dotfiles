#!/usr/bin/env bash

SESSION=$(tmux display-message -p '#S')
WINDOW=$(tmux display-message -p '#I')

if tmux list-windows -F "#{window_name}" | grep -q "^todo-hidden$"; then
    tmux join-pane -h -s "todo-hidden" -l 30%
    tmux select-pane -T "todo-sidebar"
else
    if tmux list-panes -F "#{pane_title}" | grep -q "^todo-sidebar$"; then
        TODO_PANE=$(tmux list-panes -F "#{pane_id} #{pane_title}" | grep "todo-sidebar$" | cut -d' ' -f1)
        tmux break-pane -d -s "${TODO_PANE}" -n "todo-hidden"
    else
        tmux split-window -h -l 30% -c "#{pane_current_path}" "hx ~/Desktop/state/scratchpads/todo.md"
        tmux select-pane -T "todo-sidebar"
    fi
fi
