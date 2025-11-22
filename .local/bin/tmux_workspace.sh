#!/usr/bin/env bash

# shellcheck disable=SC2016
COLORIZER_AWK='
{
  lines[NR] = $0
  n = split($0, parts, "/")
  base = parts[n]
  counts[base]++
}
END {
  c_green = "\033[1;32m"
  c_reset = "\033[0m"

  for (i=1; i<=NR; i++) {
    clean_line = lines[i]
    n = split(clean_line, parts, "/")

    if (counts[parts[n]] > 1 && n > 1) {
       target = n - 1
    } else {
       target = n
    }

    parts[target] = c_green parts[target] c_reset

    colored_line = parts[1]
    for (j=2; j<=n; j++) colored_line = colored_line "/" parts[j]

    print clean_line "|" colored_line
  }
}'

if [[ -z $TMUX ]]; then
  while true; do
    raw_input=$(
      {
        echo "$HOME"
        find -L "$HOME/Desktop" "$HOME/Downloads" -mindepth 1 -maxdepth 1 -type d ! -name ".*"
      } \
        | sed "s|^${HOME}|~|" \
        | awk "$COLORIZER_AWK" \
        | fzf --ansi --delimiter='|' --with-nth 2 --prompt="Select project: " \
        | cut -d'|' -f 1
    )
    [[ -n $raw_input ]] && break
  done
else
  raw_input=$(
    {
      echo "$HOME"
      find -L "$HOME/Desktop" "$HOME/Downloads" -mindepth 1 -maxdepth 1 -type d ! -name ".*"
    } \
      | sed "s|^${HOME}|~|" \
      | awk "$COLORIZER_AWK" \
      | fzf --ansi --delimiter='|' --with-nth 2 --prompt="Select project: " \
      | cut -d'|' -f 1
  )
fi

if [[ -z $raw_input ]]; then
  echo "No directory selected."
  exit 0
fi

path_to_resolve="$raw_input"

if [[ $path_to_resolve == "~"* ]]; then
  if [[ -z $HOME ]]; then
    echo "Error: HOME environment variable is not set." >&2
    exit 1
  fi
  path_to_resolve="${path_to_resolve/#\~/$HOME}"
fi

selected=$(realpath -e "$path_to_resolve" 2> /dev/null)

if [[ $? -ne 0 || ! -d $selected ]]; then
  echo "Error: Resolved path '$path_to_resolve' is not a valid directory." >&2
  echo "(Attempted resolution: '$selected')" >&2
  exit 1
fi

git_target=""

if [[ -d "$selected/.bare" ]]; then
  git_target="$selected/.bare"
elif [[ -d "$selected/.git" ]]; then
  if [[ "$(git -C "$selected/.git" rev-parse --is-bare-repository 2> /dev/null)" == "true" ]]; then
    git_target="$selected/.git"
  fi
elif [[ "$(git -C "$selected" rev-parse --is-bare-repository 2> /dev/null)" == "true" ]]; then
  git_target="$selected"
fi

if [[ -n $git_target ]]; then
  worktrees=$(git -C "$git_target" worktree list --porcelain | grep "^worktree " | cut -d ' ' -f 2 | grep -vFx "$git_target" | grep -vFx "$selected")

  target_wt=""

  if [[ -n $worktrees ]]; then
    for branch in "main" "master" "default" "dev" "develop"; do
      match=$(echo "$worktrees" | grep "/$branch$")
      if [[ -n $match ]]; then
        target_wt=$(echo "$match" | head -n 1)
        break
      fi
    done

    if [[ -z $target_wt ]]; then
      target_wt=$(echo "$worktrees" | head -n 1)
    fi

    if [[ -n $target_wt ]]; then
      selected="$target_wt"
    fi
  fi
fi

selected_path_hash=$(echo -n "$selected" | md5sum | awk '{ print $1 }')
session_name=$(basename "$selected")_$selected_path_hash

if ! tmux info &> /dev/null; then
  echo "No tmux server found. Starting new session '$session_name'..."
  exec tmux new-session -s "$session_name" -c "$selected"
else
  echo "Tmux server found."
  if ! tmux has-session -t="$session_name" 2> /dev/null; then
    echo "Session '$session_name' not found. Creating detached session..."
    if ! tmux new-session -ds "$session_name" -c "$selected"; then
      echo "Error: Failed to create tmux session '$session_name'." >&2
      exit 1
    fi
  fi

  if [[ -n $TMUX ]]; then
    echo "Already inside tmux. Switching client to session '$session_name'..."
    tmux switch-client -t "$session_name"
  else
    echo "Outside tmux. Attaching to session '$session_name'..."
    exec tmux attach-session -t "$session_name"
  fi
fi
