#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""

usage() {
  cat << USAGE >&2
usage: $(basename "$0") --repo-path PATH

  --repo-path PATH  Absolute path to a git working tree.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-path)
      REPO_PATH="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "state-autocommit: unexpected arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$REPO_PATH" ]; then
  echo "state-autocommit: --repo-path is required" >&2
  usage
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "state-autocommit: repo path does not exist: $REPO_PATH" >&2
  exit 2
fi

cd "$REPO_PATH"

if [ ! -d ".git" ] && ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "state-autocommit: not a git repo: $REPO_PATH" >&2
  exit 2
fi

if [ -z "$(git status --porcelain)" ]; then
  echo "state-autocommit: no changes in $REPO_PATH - nothing to commit"
  exit 0
fi

git add .

COMMIT_MSG="Auto-commit on $(date +'%Y-%m-%d %H:%M:%S')"
CHANGED_FILES=$(git status --porcelain | awk '{print "  - "$2}')
if [ -n "$CHANGED_FILES" ]; then
  COMMIT_MSG+=$'\n\nChanges:\n'"$CHANGED_FILES"
fi

git commit --no-gpg-sign -m "$COMMIT_MSG"
echo "state-autocommit: created new commit in $REPO_PATH"
