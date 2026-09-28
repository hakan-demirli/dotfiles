#!/usr/bin/env bash
set -euo pipefail

readonly NTFY_URL="http://vps-oracle-0:8111/emre-opencode"
readonly DESKTOP_HOST="laptop-1"

usage() {
  cat << USAGE >&2
usage: $(basename "$0") EVENT PROJECT

  EVENT    opencode-notifier event: permission, question, error, or complete.
  PROJECT  Project folder name of the session.
USAGE
}

if [ $# -ne 2 ]; then
  usage
  exit 1
fi

EVENT="$1"
PROJECT="$2"
HOST="$(hostname)"

if [ "$HOST" = "$DESKTOP_HOST" ]; then
  exit 0
fi

case "$EVENT" in
  permission)
    TITLE="$PROJECT needs permission"
    PRIORITY="high"
    ;;
  question)
    TITLE="$PROJECT has a question"
    PRIORITY="high"
    ;;
  error)
    TITLE="$PROJECT stopped with an error"
    PRIORITY="high"
    ;;
  complete)
    TITLE="$PROJECT finished"
    PRIORITY="default"
    ;;
  *)
    TITLE="$PROJECT: $EVENT"
    PRIORITY="default"
    ;;
esac

SEQUENCE="opencode-$HOST-$PROJECT"
SEQUENCE="${SEQUENCE//[^A-Za-z0-9_-]/-}"
SEQUENCE="${SEQUENCE:0:64}"

if command -v tnotify.sh > /dev/null 2>&1; then
  tnotify.sh "$TITLE on $HOST" > /dev/null 2>&1 || true
fi

curl -fsS --max-time 10 \
  -H "Title: $TITLE" \
  -H "Priority: $PRIORITY" \
  -H "Tags: $EVENT" \
  -H "X-Sequence-ID: $SEQUENCE" \
  -d "on $HOST" \
  "$NTFY_URL" > /dev/null
