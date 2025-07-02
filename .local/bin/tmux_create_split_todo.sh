#!/usr/bin/env bash

# Script to toggle a todo sidebar pane
SESSION=$(tmux display-message -p '#S')
WINDOW=$(tmux display-message -p '#I')

# Check if todo-hidden window exists
if tmux list-windows -F "#{window_name}" | grep -q "^todo-hidden$"; then
    # Todo window exists, join it back as a pane
    tmux join-pane -h -s "todo-hidden" -l 30%
    tmux select-pane -T "todo-sidebar"
    # tmux select-pane -L  # Return focus to main pane
else
    # Check if todo pane exists in current window
    if tmux list-panes -F "#{pane_title}" | grep -q "^todo-sidebar$"; then
        # Todo pane exists, hide it by breaking into window
        TODO_PANE=$(tmux list-panes -F "#{pane_id} #{pane_title}" | grep "todo-sidebar$" | cut -d' ' -f1)
        tmux break-pane -d -s "${TODO_PANE}" -n "todo-hidden"
    else
        # No todo pane or window exists, create new one
        tmux split-window -h -l 30% -c "#{pane_current_path}" "hx ~/Desktop/gdrive/software/scratchpads/todo.md"
        tmux select-pane -T "todo-sidebar"
        # tmux select-pane -L  # Return focus to main pane
    fi
fi
