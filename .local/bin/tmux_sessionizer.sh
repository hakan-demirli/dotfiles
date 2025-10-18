#!/usr/bin/env bash

if [[ -z "$TMUX" ]]; then
  while true; do
    raw_input=$(
      {
        echo "$HOME"
        find -L "$HOME/Desktop" "$HOME/Downloads" -mindepth 1 -maxdepth 1 -type d ! -name ".*"
      } |
      sed "s|^${HOME}|~|" |
      fzf --prompt="Select project: "
    )
    [[ $? -eq 0 ]] && break
  done
else
  raw_input=$(
    {
      echo "$HOME"
      find -L "$HOME/Desktop" "$HOME/Downloads" -mindepth 1 -maxdepth 1 -type d ! -name ".*"
    } |
    sed "s|^${HOME}|~|" |
    fzf --prompt="Select project: "
  )
fi

if [[ -z "$raw_input" ]]; then
  echo "No directory selected."
  exit 0
fi

path_to_resolve="$raw_input"

if [[ "$path_to_resolve" == "~"* ]]; then
    if [[ -z "$HOME" ]]; then
        echo "Error: HOME environment variable is not set." >&2
        exit 1
    fi
    path_to_resolve="${path_to_resolve/#\~/$HOME}"
fi

selected=$(realpath -e "$path_to_resolve" 2>/dev/null)

if [[ $? -ne 0 || ! -d "$selected" ]]; then
  echo "Error: Resolved path '$path_to_resolve' is not a valid directory." >&2
  echo "(Attempted resolution: '$selected')" >&2
  exit 1
fi

selected_base_name=$(basename "$selected" | tr --complement --squeeze '[:alnum:]' '_')
selected_base_name=${selected_base_name#_}
selected_base_name=${selected_base_name%_}
selected_path_hash=$(echo -n "$selected" | md5sum | awk '{ print $1 }')
session_name="${selected_base_name}_${selected_path_hash}"

if ! tmux info &>/dev/null; then
  echo "No tmux server found. Starting new session '$session_name'..."
  exec tmux new-session -s "$session_name" -c "$selected"
else
  echo "Tmux server found."
  if ! tmux has-session -t="$session_name" 2>/dev/null; then
    echo "Session '$session_name' not found. Creating detached session..."
    tmux new-session -ds "$session_name" -c "$selected"
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to create tmux session '$session_name'." >&2
      exit 1
    fi
  fi

  if [[ -n "$TMUX" ]]; then
    echo "Already inside tmux. Switching client to session '$session_name'..."
    tmux switch-client -t "$session_name"
  else
    echo "Outside tmux. Attaching to session '$session_name'..."
    exec tmux attach-session -t "$session_name"
  fi
fi
