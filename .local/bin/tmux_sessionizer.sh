#!/usr/bin/env bash

tmux list-sessions -F "#{session_name}|#{=15:session_name}: #{s|$HOME|~|:session_path}" \
  | awk '
    BEGIN { FS="|"; OFS="|" }
    {
        lines[NR] = $0
        split($2, meta, ": ")
        path = meta[2]
        n = split(path, dirs, "/")
        basename = dirs[n]
        counts[basename]++
    }
    END {
        c_green = "\033[1;32m"
        c_reset = "\033[0m"

        for (i=1; i<=NR; i++) {
            split(lines[i], parts, "|")
            split(parts[2], meta, ": ")
            path_str = meta[2]

            n = split(path_str, path_arr, "/")
            current_base = path_arr[n]

            if (counts[current_base] > 1 && n > 1) {
                target = n - 1
            } else {
                target = n
            }

            label_text = path_arr[target]

            if (length(label_text) > 15) {
                label_text = substr(label_text, 1, 15)
            }
            padding = ""
            if (length(label_text) < 15) {
                padding = sprintf("%*s", 15 - length(label_text), "")
            }
            label_col = c_green label_text c_reset padding

            session_col = sprintf("%-15s", meta[1])
            path_arr[target] = c_green path_arr[target] c_reset
            new_path = path_arr[1]
            for (j=2; j<=n; j++) {
                new_path = new_path "/" path_arr[j]
            }

            print parts[1] "|" label_col " " session_col ": " new_path
        }
    }
' \
  | fzf --ansi -d '|' \
    --with-nth 2 \
    --preview 'tmux capture-pane -ep -t {1}' \
    --bind 'enter:execute(tmux switch-client -t {1})+accept'
