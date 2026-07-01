#!/usr/bin/env bash
set -euo pipefail

tmp="$(mktemp)"
yazi --cwd-file="$tmp" "$@"
if [ -f "$tmp" ]; then
  dir="$(command cat "$tmp")"
  rm -f "$tmp"
  if [ -d "$dir" ]; then
    if [ "$dir" != "$(pwd)" ]; then
      cd "$dir" || exit
      exec "${SHELL:-sh}"
    fi
  fi
fi
