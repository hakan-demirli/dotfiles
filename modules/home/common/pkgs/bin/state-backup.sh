#!/usr/bin/env bash
set -euo pipefail

repo=$1
branch=$2
remote=$3
history_file=$4
local_dir=$(dirname "$history_file")
target="$repo/.local/state/bash/history"
checkout=""
staged=""
trap 'if [[ -n $checkout ]]; then rm -rf "$checkout"; fi; if [[ -n $staged ]]; then rm -f "$staged"; fi' EXIT
trap 'exit 143' TERM
umask 077

export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"
mkdir -p "$(dirname "$repo")" "$(dirname "$local_dir")"
exec 9> "$repo.lock"
flock -w 30 9

if [[ ! -d $repo/.git ]] || [[ $(git -C "$repo" symbolic-ref --quiet --short HEAD) != "$branch" ]]; then
  if [[ -L $local_dir || -L $history_file ]]; then
    staged=$(mktemp "$(dirname "$local_dir")/.history.XXXXXX")
    if [[ -f $history_file ]]; then
      cp -pL "$history_file" "$staged"
    fi
    if [[ -L $local_dir ]]; then
      rm "$local_dir"
    fi
    mkdir -p "$local_dir"
    mv -T "$staged" "$history_file"
    staged=""
  else
    mkdir -p "$local_dir"
    touch "$history_file"
  fi
fi

git check-ref-format --branch "$branch" > /dev/null
repo=$(realpath -m "$repo")
target="$repo/.local/state/bash/history"
if [[ ! -e $repo && ! -L $repo ]]; then
  checkout=$(mktemp -d "$repo.checkout.XXXXXX")
  git clone "$remote" "$checkout"
  mv --no-clobber --no-target-directory "$checkout" "$repo"
  [[ ! -e $checkout ]]
  checkout=""
elif [[ -d $repo && ! -e $repo/.git ]]; then
  git clone "$remote" "$repo"
fi

[[ $(git -C "$repo" rev-parse --show-toplevel) == "$repo" ]]
exec 8> "$(git -C "$repo" rev-parse --path-format=absolute --git-path state-sync.lock)"
flock -w 30 8

if [[ $(git -C "$repo" symbolic-ref --quiet --short HEAD) == "$branch" ]]; then
  :
elif git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$repo" switch "$branch"
elif git -C "$repo" ls-remote --exit-code --heads origin "refs/heads/$branch"; then
  git -C "$repo" fetch origin "refs/heads/$branch:refs/remotes/origin/$branch"
  git -C "$repo" switch --track -c "$branch" "origin/$branch"
else
  result=$?
  [[ $result == 2 ]] || exit "$result"
  if git -C "$repo" rev-parse --verify HEAD > /dev/null 2>&1; then
    git -C "$repo" switch -c "$branch"
  else
    git -C "$repo" symbolic-ref HEAD "refs/heads/$branch"
  fi
fi

mkdir -p "$local_dir" "$(dirname "$target")"
touch "$target"
ln -sfnT "$target" "$history_file"
git -C "$repo" add -- .local/state/bash/history
if ! git -C "$repo" diff --cached --quiet -- .local/state/bash/history; then
  git -C "$repo" commit --no-gpg-sign --only -m "Auto-commit on $(date +'%Y-%m-%d %H:%M:%S')" -- .local/state/bash/history
fi
git -C "$repo" push origin "$branch"
