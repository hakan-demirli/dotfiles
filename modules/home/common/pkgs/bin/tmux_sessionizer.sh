#!/usr/bin/env bash
set -euo pipefail

current_session=${1-}

sessions=$(tmux list-sessions -F '#{session_id}|#{session_name}|#{session_path}' \
  | while IFS='|' read -r session_id session_name session_path; do
    label=$(tmux_harpoon_session_name.sh "$session_path")
    display_path=$session_path
    if [[ $display_path == "$HOME" || $display_path == "$HOME/"* ]]; then
      display_path="~${display_path#"$HOME"}"
    fi
    printf '%s\t%s\t%s\t%s\n' "$session_id" "$session_name" "$label" "$display_path"
  done \
  | awk -F '\t' '
    {
        lines[NR] = $0
        n = split($4, dirs, "/")
        basename = dirs[n]
        counts[basename]++
    }
    END {
        c_green = "\033[1;32m"
        c_reset = "\033[0m"

        for (i=1; i<=NR; i++) {
            split(lines[i], parts, "\t")
            path_str = parts[4]

            n = split(path_str, path_arr, "/")
            current_base = path_arr[n]

            if (counts[current_base] > 1 && n > 1) {
                target = n - 1
            } else {
                target = n
            }

            session_col = c_green sprintf("%-20s", parts[3]) c_reset
            path_arr[target] = c_green path_arr[target] c_reset
            new_path = path_arr[1]
            for (j=2; j<=n; j++) {
                new_path = new_path "/" path_arr[j]
            }

            print parts[1] "\t" parts[2] "\t" session_col ": " new_path
        }
    }
')

current_session_pos=$(awk -F '\t' -v current="$current_session" '
  $2 == current && pos == 0 { pos = NR }
  END { print pos + 0 }
' <<< "$sessions")

fzf_bind_args=()
if [[ $current_session_pos -gt 0 ]]; then
  fzf_bind_args=(--sync "--bind=start:pos($current_session_pos)")
fi

fzf --ansi -d $'\t' "${fzf_bind_args[@]}" \
  --with-nth 3 \
  --preview 'tmux capture-pane -ep -t {1}' \
  --bind 'enter:execute(tmux switch-client -t {1})+accept' \
  --bind 'alt-u:pos(1)+execute(tmux switch-client -t {1})+accept' \
  --bind 'alt-i:pos(2)+execute(tmux switch-client -t {1})+accept' \
  --bind 'alt-o:pos(3)+execute(tmux switch-client -t {1})+accept' \
  --bind 'alt-p:pos(4)+execute(tmux switch-client -t {1})+accept' \
  <<< "$sessions" || {
  status=$?
  case $status in
    1 | 130) ;;
    *) exit "$status" ;;
  esac
}
