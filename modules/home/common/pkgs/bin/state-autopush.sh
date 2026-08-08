#!/usr/bin/env bash
set -euo pipefail

REPO_PATH=""
BRANCH=""

usage() {
  cat << USAGE >&2
usage: $(basename "$0") --repo-path PATH --branch NAME

  --repo-path PATH  Absolute path to a git working tree.
  --branch NAME     Branch name to push.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-path)
      REPO_PATH="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "state-autopush: unexpected arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$REPO_PATH" ] || [ -z "$BRANCH" ]; then
  echo "state-autopush: --repo-path and --branch are both required" >&2
  usage
  exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
  echo "state-autopush: repo path does not exist: $REPO_PATH" >&2
  exit 2
fi

cd "$REPO_PATH"

if [ ! -d ".git" ] && ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "state-autopush: not a git repo: $REPO_PATH" >&2
  exit 2
fi

echo "state-autopush: pushing $BRANCH from $REPO_PATH"
if ! git push origin "$BRANCH"; then
  echo "state-autopush: git push failed for branch '$BRANCH'" >&2
  exit 3
fi
echo "state-autopush: push complete"
