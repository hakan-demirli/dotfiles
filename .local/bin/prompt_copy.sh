#!/usr/bin/env bash
PROMPTS_PATH="${PROMPTS_PATH:-$HOME/Desktop/notes/notes/work/topics/ai/prompts/}"

if [[ ! -d $PROMPTS_PATH ]]; then
  echo "Error: Prompts directory not found at '$PROMPTS_PATH'" >&2
  exit 1
fi

copy_to_clipboard() {
  local content="$1"

  if [[ -z $SSH_CONNECTION ]] && command -v wl-copy &> /dev/null; then
    printf "%s" "$content" | wl-copy
    return 0
  fi

  if [[ -n $TMUX ]]; then
    local tty
    tty=$(tmux display-message -p '#{client_tty}')
    printf "\e]52;c;%s\a" "$(printf "%s" "$content" | base64 --wrap=0)" > "$tty"
    return 0
  else

    printf "\e]52;c;%s\a" "$(printf "%s" "$content" | base64 --wrap=0)"
    return 0
  fi
}

while true; do
  if ! selected_file=$(
    find "$PROMPTS_PATH" -maxdepth 1 -type f -printf "%f\n" \
      | fzf --prompt="Select prompt to copy > " \
        --preview="cat '${PROMPTS_PATH}/{}'" \
        --layout=reverse
  ); then
    echo "No prompt selected. Exiting."
    break
  fi

  if [[ -z $selected_file ]]; then
    continue
  fi

  full_path="${PROMPTS_PATH}/${selected_file}"
  if [[ ! -f $full_path ]]; then
    echo "Error: File '$selected_file' seems to have disappeared." >&2
    sleep 2
    continue
  fi

  content_to_copy=$(cat "$full_path")
  if copy_to_clipboard "$content_to_copy"; then
    echo "Copied content of '$selected_file' to clipboard!"
    sleep 0.1
  else
    echo "Error: Failed to copy to clipboard." >&2
    sleep 3
  fi
done
