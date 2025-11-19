#!/usr/bin/env bash

lf_cd() {
  if command -v lf &> /dev/null; then
    cd "$(command lf -print-last-dir "$@")" || exit
  else
    echo "Command 'lf' not found. Please install it."
  fi
}

yazi_cd() {
  if ! command -v yazi &> /dev/null; then
    echo "Command 'yazi' not found. Please install it."
    return 1
  fi

  mkdir -p "$TMPDIR" 2> /dev/null
  tmp="$(mktemp -t "yazi-cwd.XXXXX")"

  yazi --cwd-file="$tmp"

  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd -- "$cwd" || exit
  fi

  rm -f -- "$tmp"
}

gcmp() {
  if [ -z "$1" ]; then
    echo 'Usage: gcmp "Your commit message"'
    return 1
  fi
  git commit -m "$1" && git push
}

_copy_readline_to_clipboard_local() {
  echo -n "$READLINE_LINE" | wl-copy
}

_copy_readline_to_clipboard_remote() {
  printf '\e]52;c;%s\a' "$(echo -n "$READLINE_LINE" | base64 -w0)"
}

ensure_prompt_symbol() {
  if [[ $PS1 != *❯* ]]; then
    PS1="${PS1}\n❯ "
  fi
}

gitexplode() {
  if [ ! -d ".git" ]; then
    echo "Error: Must be run from the root of a standard git repository."
    return 1
  fi

  if [ -d ".bare" ]; then
    echo "Error: This looks like it's already a worktree setup (.bare exists)."
    return 1
  fi

  local repo_name
  repo_name=$(basename "$PWD")

  local current_branch
  current_branch=$(git branch --show-current)

  if [ -z "$current_branch" ]; then
    current_branch=$(git rev-parse --abbrev-ref HEAD)
  fi

  if [ -z "$current_branch" ] || [ "$current_branch" = "HEAD" ]; then
    echo "Error: Could not determine a valid branch name. Checkout a branch first."
    return 1
  fi

  echo "Exploding '$repo_name' into worktree structure."
  echo "Target Branch/Folder: $current_branch"

  mkdir -p .temp_files

  (
    shopt -s extglob dotglob
    mv !(.git|.temp_files) .temp_files/ 2> /dev/null
  )

  mv .git .bare
  cd .bare || return 1
  git config --bool core.bare true
  cd ..

  if ! git --git-dir=.bare worktree add -f "$current_branch" "$current_branch"; then
    echo "Error: Failed to create worktree. Attempting to revert..."
    mv .bare .git
    mv .temp_files/* .
    rmdir .temp_files
    return 1
  fi

  echo "Migrating staging area (index) to new worktree..."
  if [ -f ".bare/index" ]; then
    cp ".bare/index" ".bare/worktrees/$current_branch/index"
  fi

  echo "Moving temp files to '$current_branch'..."
  cp -a .temp_files/. "$current_branch"/ 2> /dev/null || true
  rm -rf .temp_files

  if [ -n "$TMUX" ]; then
    local new_session="${repo_name}@${current_branch}"
    new_session=${new_session//\//-}
    tmux rename-session "$new_session" 2> /dev/null
    echo "Session renamed to: $new_session"
  fi

  cd "$current_branch" || return 1
  echo "Done. You are now in '$current_branch'."
}

gwn() {
  if [ -z "$1" ]; then
    echo "Usage: gwn <branch-name>"
    return 1
  fi

  local branch="$1"
  local new_dir="../$branch"

  if [ -d "$new_dir" ]; then
    echo "Directory '../$branch' already exists."
    return 1
  fi

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$new_dir" "$branch"
  else
    git worktree add -b "$branch" "$new_dir"
  fi
}

gwd() {
  if [ -z "$1" ]; then
    echo "Usage: gwd <branch-name>"
    return 1
  fi

  local branch="$1"
  local target_dir="../$branch"

  if [ ! -d "$target_dir" ]; then
    echo "Directory '$target_dir' does not exist."
    return 1
  fi

  read -p "Delete worktree '$branch'? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then return 1; fi

  git worktree remove --force "$target_dir"
}
