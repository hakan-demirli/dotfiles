#!/usr/bin/env bash
set -euo pipefail

SSH_CONFIG="${SSH_CONFIG:-$HOME/.ssh/config}"

{
  if [[ -r $SSH_CONFIG ]]; then
    awk '
      $1 == "Host" {
        for (i = 2; i <= NF && $i !~ /^#/; i++) {
          if ($i !~ /[*?!]/) print $i
        }
      }
    ' "$SSH_CONFIG"
  fi

  if command -v tailscale > /dev/null 2>&1 && command -v jq > /dev/null 2>&1; then
    tailscale status --json 2> /dev/null \
      | jq -r '(.Peer // {}) | .[] | (.DNSName // empty) | rtrimstr(".")' 2> /dev/null \
      || true
  fi
} | awk 'NF && !seen[$0]++'
