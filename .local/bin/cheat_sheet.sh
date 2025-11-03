#!/usr/bin/env bash

notesPath="${CHEATSHEETNOTESPATH:-$HOME/Desktop/notes/notes/work/coding/cheatsheet/}"
linuxNotesPath="${CHEATSHEETLINUXNOTESPATH:-$HOME/Desktop/dotfiles/doc/notes/}"
linuxNoteExtension=".md"
EDITOR="${EDITOR:-vim}"

while true; do
  sheets=$(find "$notesPath" -maxdepth 1 -name '*.md' -printf "%f\n" | sed "s/${linuxNoteExtension}$//")
  options=$(printf "%s\nlinux" "$sheets")

  selected_clean=$(echo "$options" | fzf --prompt="Select Cheat Sheet > ")
  exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    echo "Exiting."
    break
  fi

  if [[ "$selected_clean" == "linux" ]]; then

    linux_lines_for_fzf=$(rg --color never --line-number --no-heading . "$linuxNotesPath" 2>/dev/null |
      sed -E "s|^${linuxNotesPath}/?([^/]+)${linuxNoteExtension}:([0-9]+):(.*)|\1:\2:\3|")

    if [[ -z "$linux_lines_for_fzf" ]]; then
      echo "No lines found in '$linuxNotesPath' or rg failed." >&2
      sleep 2
      continue
    fi

    linux_selection=$(echo "$linux_lines_for_fzf" |
      fzf --prompt="Search Linux Notes (file:line:content) > " --delimiter=":" --preview="echo {}") # Simple preview

    linux_exit_code=$?

    if [[ $linux_exit_code -ne 0 || -z "$linux_selection" ]]; then
      continue
    fi

    base_name=$(echo "$linux_selection" | cut -d: -f1)
    line_num=$(echo "$linux_selection" | cut -d: -f2)

    if [[ -n "$base_name" && "$line_num" =~ ^[0-9]+$ && "$line_num" -gt 0 ]]; then
      full_path="${linuxNotesPath}/${base_name}${linuxNoteExtension}"

      if [[ -f "$full_path" ]]; then
        case "$(basename "$EDITOR")" in
        code | subl | atom) "$EDITOR" -g "${full_path}:${line_num}" ;;
        *) "$EDITOR" "+${line_num}" "$full_path" ;;
        esac
      else
        echo "Error: Reconstructed file path not found: '$full_path'" >&2
        sleep 2
      fi
    else
      echo "Error: Could not parse selection format: '$linux_selection'" >&2
      sleep 2
    fi

  else
    selected="${selected_clean}${linuxNoteExtension}"
    full_path="${notesPath}${selected}"

    if [[ -f "$full_path" ]]; then
      "$EDITOR" "$full_path"
    else
      echo "Error: File not found: $full_path" >&2
      sleep 2
    fi
  fi
done
