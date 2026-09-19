#!/usr/bin/env bash
set -euo pipefail

repo=$(realpath -m "$1")
branch=$2
remote=$3
shift 3

export GIT_TERMINAL_PROMPT=0
umask 077

if [[ ! -d $repo/.git ]]; then
  exit 0
fi

exec 9> "$(git -C "$repo" rev-parse --path-format=absolute --git-path notes-backup.lock)"
flock -w 30 9

[[ $(git -C "$repo" rev-parse --show-toplevel) == "$repo" ]]
[[ $(git -C "$repo" remote get-url origin) == "$remote" ]]

current=$(git -C "$repo" symbolic-ref --quiet --short HEAD)
if [[ $current != "$branch" ]]; then
  echo "$repo is on $current, refusing to back up $branch" >&2
  exit 1
fi

git -C "$repo" add -- "$@"
if ! git -C "$repo" diff --cached --quiet -- "$@"; then
  git -C "$repo" commit --no-gpg-sign --only -m "Auto-commit on $(date +'%Y-%m-%d %H:%M:%S')" -- "$@"
fi
git -C "$repo" push origin "$branch"
