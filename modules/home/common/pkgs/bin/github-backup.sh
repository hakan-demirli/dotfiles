#!/usr/bin/env bash
set -euo pipefail

USER=""
CLONE_TO=""
EXCLUDE_REGEX=""

usage() {
  cat << USAGE >&2
usage: $(basename "$0") --user USER --clone-to PATH [--exclude REGEX]

  --user USER          GitHub user or org to mirror.
  --clone-to PATH      Absolute directory to clone repos into.
  --exclude REGEX      Optional regex. Matching repo names are skipped.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user)
      USER="$2"
      shift 2
      ;;
    --clone-to)
      CLONE_TO="$2"
      shift 2
      ;;
    --exclude)
      EXCLUDE_REGEX="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "github-backup: unexpected arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ -z "$USER" ] || [ -z "$CLONE_TO" ]; then
  echo "github-backup: --user and --clone-to are required" >&2
  usage
  exit 1
fi

if ! command -v ghorg > /dev/null 2>&1; then
  echo "github-backup: 'ghorg' not on PATH" >&2
  exit 2
fi

if [ -z "${GH_TOKEN:-}" ]; then
  echo "github-backup: GH_TOKEN is not set" >&2
  exit 3
fi

mkdir -p "$CLONE_TO"

export GHORG_SCM_TYPE="github"
export GHORG_CLONE_TYPE="user"
export GHORG_BASE_URL="https://api.github.com/"
export GHORG_ABSOLUTE_PATH_TO_CLONE_TO="$CLONE_TO"
export GHORG_CLONE_WIKI="true"
export GHORG_PRUNE="true"
export GHORG_PRUNE_NO_CONFIRM="true"
export GHORG_SKIP_ARCHIVED="false"
export GHORG_SKIP_FORKS="true"
export GHORG_GITHUB_TOKEN="$GH_TOKEN"

if [ -n "$EXCLUDE_REGEX" ]; then
  ghorg clone "$USER" --exclude-match-regex "$EXCLUDE_REGEX"
else
  ghorg clone "$USER"
fi
