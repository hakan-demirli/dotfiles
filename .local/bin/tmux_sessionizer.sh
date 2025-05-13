#!/usr/bin/env bash

raw_input=""

if [[ $# -eq 1 ]]; then
  raw_input=$1
else
  search_dirs=("$HOME/Desktop" "$HOME/Downloads")

  valid_search_dirs=()
  for dir in "${search_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      valid_search_dirs+=("$dir")
    else
      echo "Warning: Search directory '$dir' not found." >&2
    fi
  done

  if [[ ${#valid_search_dirs[@]} -eq 0 ]]; then
    echo "Error: No valid search directories found (${search_dirs[*]})." >&2
    exit 1
  fi

  dir_list=""
  if command -v fd &>/dev/null; then
    mapfile -d '' dir_array < <(fd --follow --type d --max-depth 1 --exclude ".*" . "${valid_search_dirs[@]}" --print0)
    dir_list=$(printf "%s\n" "${dir_array[@]}")
  else
    mapfile -d '' dir_array < <(find -L "${valid_search_dirs[@]}" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -print0)
    dir_list=$(printf "%s\n" "${dir_array[@]}")
  fi

  if [[ -z "$dir_list" ]]; then
    echo "No directories found in specified search locations."
    exit 0
  fi

  display_list=""
  if [[ -n "$HOME" ]] && [[ "$HOME" != "/" ]]; then
    display_list=$(echo "$dir_list" | sed "s|^${HOME}|~|")
  else
    display_list="$dir_list"
  fi

  selected_display=$(echo -e "$display_list" | fzf --prompt="Select project: ")

  if [[ -n "$selected_display" ]]; then
    raw_input="$selected_display"
  else
    raw_input=""
  fi
fi

if [[ -z "$raw_input" ]]; then
  echo "No directory selected."
  exit 0
fi

path_to_resolve="$raw_input"

if [[ "$path_to_resolve" == "~" ]]; then
  if [[ -z "$HOME" ]]; then
    echo "Error: HOME not set." >&2
    exit 1
  fi
  path_to_resolve="$HOME"
elif [[ "$path_to_resolve" == "~/"* ]]; then
  if [[ -z "$HOME" ]]; then
    echo "Error: HOME not set." >&2
    exit 1
  fi
  path_to_resolve="$HOME/${path_to_resolve#\~/}"
fi

selected=$(realpath -e "$path_to_resolve" 2>/dev/null)

if [[ $? -ne 0 || ! -d "$selected" ]]; then
  echo "Error: Resolved path '$path_to_resolve' is not a valid directory." >&2
  echo "(Attempted resolution: '$selected')" >&2
  exit 1
fi

selected_name=$(basename "$selected" | tr --complement --squeeze '[:alnum:]' '_')

selected_name=${selected_name#_}
selected_name=${selected_name%_}

if [[ -z "$selected_name" ]]; then
  selected_name="default_session"
fi

if ! tmux info &>/dev/null; then
  echo "No tmux server found. Starting new session '$selected_name'..."
  exec tmux new-session -s "$selected_name" -c "$selected"
else
  echo "Tmux server found."
  if ! tmux has-session -t="$selected_name" 2>/dev/null; then
    echo "Session '$selected_name' not found. Creating detached session..."
    tmux new-session -ds "$selected_name" -c "$selected"
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to create tmux session '$selected_name'." >&2
      exit 1
    fi
  fi

  if [[ -n "$TMUX" ]]; then
    echo "Already inside tmux. Switching client to session '$selected_name'..."
    tmux switch-client -t "$selected_name"
  else
    echo "Outside tmux. Attaching to session '$selected_name'..."
    exec tmux attach-session -t "$selected_name"
  fi
fi
