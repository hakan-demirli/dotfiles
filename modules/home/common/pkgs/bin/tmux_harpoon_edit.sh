#!/usr/bin/env bash

tmux_cwd=$(tmux display-message -p '#{session_path}')
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum | awk '{ print $1 }')
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"

mkdir -p "$cache_dir"
if [[ ! -s $data_file ]]; then
  tmux_pane_path=$(tmux display-message -p '#{pane_current_path}')
  {
    for i in {0..3}; do
      echo "$i,bash,::,,$tmux_pane_path"
    done
    echo
    echo "# session_name: $(basename "$tmux_cwd")"
    echo "# pane_id , command , file_name:r:c , file_path , workspace_dir"
  } > "$data_file"
fi

tmux display-popup -w 80% -E "hx $data_file"

sed -i '/^$/d' "$data_file"
tmux refresh-client -S
