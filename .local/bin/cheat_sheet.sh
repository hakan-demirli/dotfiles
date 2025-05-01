#!/usr/bin/env bash

notesPath="${CHEATSHEETNOTESPATH:-$HOME/Desktop/notes/notes/work/coding/cheatsheet/}"

while true; do
  sheets=$(ls "$notesPath")
  sheets_clean=$(echo "$sheets" | tr -d ".md")

  selected_clean=$(echo "$sheets_clean" | fzf)

  exit_code=$?

  # Exit loop on Ctrl+C or Ctrl+D
  if [[ $exit_code -ne 0 ]]; then
    break
  fi

  selected="${selected_clean}.md"
  full_path="${notesPath}${selected}"

  [[ -f $full_path ]] || continue

  "$EDITOR" "$full_path"
done
