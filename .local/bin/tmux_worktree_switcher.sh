#!/usr/bin/env bash
set -euo pipefail

current_path=$(tmux display-message -p "#{pane_current_path}")
project_root=$(dirname "$current_path")
repo_name=$(basename "$project_root")

if [ ! -d "$project_root/.bare" ]; then
  tmux display-message "Not inside a Worktree structure."
  exit 0
fi

worktrees=$(find "$project_root" -maxdepth 1 -mindepth 1 -type d ! -name ".*" -printf "%f\n")

output=$(echo "$worktrees" | fzf \
  --print-query \
  --reverse \
  --header "Select or type ':newname' to create" \
  --prompt="$repo_name > " \
  --height=40% \
  --border)

if [ -z "$output" ]; then exit 0; fi

query=$(echo "$output" | head -n 1)
selection=$(echo "$output" | tail -n +2)

target_name=""
create_new=0

if [ -n "$selection" ]; then
  target_name="$selection"
elif [[ $query == :* ]]; then
  target_name="${query:1}"
  create_new=1
else
  exit 0
fi

if [ -z "$target_name" ]; then exit 0; fi

target_path="$project_root/$target_name"

if [ $create_new -eq 1 ]; then
  if [ -d "$target_path" ]; then
    tmux display-message "Directory exists but was not in list? Aborting."
    exit 1
  fi

  if ! git -C "$current_path" worktree add -b "$target_name" "$target_path"; then
    read -pr "Git error. Press Enter..."
    exit 1
  fi

  [ -f "$project_root/main/.env" ] && cp "$project_root/main/.env" "$target_path/"
  [ -f "$project_root/main/.envrc" ] && cp "$project_root/main/.envrc" "$target_path/"

  if command -v direnv &> /dev/null; then
    (cd "$target_path" && direnv allow)
  fi
fi

absolute_target_path=$(realpath "$target_path")
path_hash=$(echo -n "$absolute_target_path" | md5sum | awk '{ print $1 }')
session_name="$(basename "$absolute_target_path")_$path_hash"

if ! tmux has-session -t="$session_name" 2> /dev/null; then
  tmux new-session -d -s "$session_name" -c "$absolute_target_path"
fi

tmux switch-client -t "$session_name"
