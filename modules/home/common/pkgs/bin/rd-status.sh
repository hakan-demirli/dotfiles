#!/usr/bin/env bash
set -euo pipefail

SUNSHINE_USER_UNIT="sunshine"
HEADLESS_SYSTEM_UNIT="remotedesktop"

if sudo -n systemctl is-active --quiet "$HEADLESS_SYSTEM_UNIT" 2> /dev/null; then
  echo "Remote desktop (headless): RUNNING"
elif systemctl --user is-active --quiet "$SUNSHINE_USER_UNIT" 2> /dev/null; then
  echo "Sunshine (desktop):        RUNNING"
else
  echo "Remote desktop: STOPPED"
fi

if command -v tailscale > /dev/null 2>&1; then
  TS_IP=$(tailscale ip -4 2> /dev/null || true)
  TS_NAME=$(tailscale status --self=true --peers=false 2> /dev/null | awk '{print $2}' || true)
  if [ -n "$TS_NAME" ]; then
    echo "Moonlight target: $TS_NAME"
  fi
  if [ -n "$TS_IP" ]; then
    echo "Moonlight IP:     $TS_IP"
  fi
  echo "Sunshine Web UI:  https://${TS_NAME:-localhost}:47990"
else
  echo "Moonlight target: $(hostname)"
  echo "Sunshine Web UI:  https://$(hostname):47990"
fi
