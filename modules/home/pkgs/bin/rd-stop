#!/usr/bin/env bash
set -euo pipefail

SUNSHINE_USER_UNIT="sunshine"
HEADLESS_SYSTEM_UNIT="remotedesktop"

stopped=false

if sudo -n systemctl is-active --quiet "$HEADLESS_SYSTEM_UNIT" 2> /dev/null; then
  echo "Stopping headless remote desktop..."
  sudo -n systemctl stop "$HEADLESS_SYSTEM_UNIT"
  stopped=true
fi

if systemctl --user is-active --quiet "$SUNSHINE_USER_UNIT" 2> /dev/null; then
  echo "Stopping Sunshine..."
  systemctl --user stop "$SUNSHINE_USER_UNIT"
  stopped=true
fi

if [ "$stopped" = true ]; then
  echo "Remote desktop stopped."
else
  echo "Remote desktop is not running."
fi
