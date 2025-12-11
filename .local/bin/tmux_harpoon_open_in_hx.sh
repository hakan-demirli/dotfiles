#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${1:-} ]] || [[ -z ${2:-} ]]; then
  tmux display-message "Error: Script requires CWD and Pane ID."
  exit 1
fi

pane_cwd="$1"
target_pane="$2"

input_path=$(xargs)

if [[ -z $input_path ]]; then
  exit 0
fi

if [[ $input_path == "~"* ]]; then
  input_path="${input_path/#\~/$HOME}"
fi

if [[ $input_path == /* ]]; then
  final_path="$input_path"
else
  final_path="$pane_cwd/$input_path"
fi

absolute_path=$(realpath -m -- "$final_path")

tmux send-keys -t "$target_pane" C-c " hx $absolute_path" Enter
