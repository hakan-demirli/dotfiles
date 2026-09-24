#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo 'Usage: gsu /path/to/upstream-repo' >&2
  exit 2
fi

git() { command git "$@"; }

[[ "$(git rev-parse --is-inside-work-tree)" == true ]] || {
  echo 'Run gsu inside your working repository.' >&2
  exit 1
}

branch="$(git symbolic-ref --quiet --short HEAD)" || {
  echo 'Check out a branch first; HEAD is detached.' >&2
  exit 1
}

target="$(cd -- "$1" && pwd -P)"
local_repo="$(git rev-parse --path-format=absolute --git-common-dir)"
upstream_repo="$(git -C "$target" rev-parse --path-format=absolute --git-common-dir)"

[[ $local_repo != "$upstream_repo" ]] || {
  echo 'The upstream must be a different repository.' >&2
  exit 1
}

if [[ "$(git -C "$target" rev-parse --is-bare-repository)" == false ]]; then
  git -C "$target" config --local receive.denyCurrentBranch updateInstead
fi

git config --local --replace-all remote.origin.url "$target"
git config --local --replace-all remote.origin.pushurl "$target"
git config --local --replace-all remote.origin.fetch \
  '+refs/heads/*:refs/remotes/origin/*'

git config --local remote.pushDefault origin
git config --local push.default current
git config --local push.autoSetupRemote true

git config --local pull.rebase false
git config --local "branch.$branch.rebase" false

git config --local "branch.$branch.remote" origin
git config --local "branch.$branch.merge" "refs/heads/$branch"
git config --local "branch.$branch.pushRemote" origin

git fetch --prune origin

printf '\norigin -> %s\n' "$target"
git status -sb
