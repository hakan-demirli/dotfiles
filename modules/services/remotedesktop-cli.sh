#!/usr/bin/env bash
set -euo pipefail

SUNSHINE_USER_UNIT="sunshine"
HEADLESS_SYSTEM_UNIT="remotedesktop"
SYSTEMCTL="${SYSTEMCTL:-/run/current-system/sw/bin/systemctl}"
SUDO="${SUDO:-/run/wrappers/bin/sudo}"

headless_active() {
  "$SUDO" -n "$SYSTEMCTL" is-active --quiet "$HEADLESS_SYSTEM_UNIT" 2> /dev/null
}

sunshine_active() {
  "$SYSTEMCTL" --user is-active --quiet "$SUNSHINE_USER_UNIT" 2> /dev/null
}

status() {
  if headless_active; then
    echo "Remote desktop (headless): RUNNING"
  elif sunshine_active; then
    echo "Sunshine (desktop):        RUNNING"
  else
    echo "Remote desktop: STOPPED"
  fi

  if command -v tailscale > /dev/null 2>&1; then
    local ts_ip ts_name
    ts_ip=$(tailscale ip -4 2> /dev/null || true)
    ts_name=$(tailscale status --self=true --peers=false 2> /dev/null | awk '{print $2}' || true)
    if [[ -n $ts_name ]]; then
      echo "Moonlight target: $ts_name"
    fi
    if [[ -n $ts_ip ]]; then
      echo "Moonlight IP:     $ts_ip"
    fi
    echo "Sunshine Web UI:  https://${ts_name:-localhost}:47990"
  else
    local host
    host=$(hostname)
    echo "Moonlight target: $host"
    echo "Sunshine Web UI:  https://$host:47990"
  fi
}

start() {
  if headless_active || sunshine_active; then
    echo "Remote desktop is already running."
    status
    return 0
  fi

  if [[ -n ${WAYLAND_DISPLAY:-} ]] \
    || [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] \
    || "$SYSTEMCTL" --user is-active --quiet graphical-session.target 2> /dev/null; then
    echo "Graphical session detected. Starting Sunshine for current display..."
    "$SYSTEMCTL" --user start "$SUNSHINE_USER_UNIT"
    sleep 1
    status
    return 0
  fi

  if "$SUDO" -n "$SYSTEMCTL" cat "$HEADLESS_SYSTEM_UNIT" &> /dev/null; then
    echo "No graphical session. Starting headless Hyprland + Sunshine..."
    "$SUDO" -n "$SYSTEMCTL" start "$HEADLESS_SYSTEM_UNIT"
    sleep 3
    status
    return 0
  fi

  echo "No graphical session and no headless service available."
  echo "Enable services.remotedesktop.headless on this host."
  return 1
}

stop() {
  local stopped=false

  if headless_active; then
    echo "Stopping headless remote desktop..."
    "$SUDO" -n "$SYSTEMCTL" stop "$HEADLESS_SYSTEM_UNIT"
    stopped=true
  fi

  if sunshine_active; then
    echo "Stopping Sunshine..."
    "$SYSTEMCTL" --user stop "$SUNSHINE_USER_UNIT"
    stopped=true
  fi

  if [[ $stopped == true ]]; then
    echo "Remote desktop stopped."
  else
    echo "Remote desktop is not running."
  fi
}

case "${1:-status}" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *)
    echo "Usage: ${0##*/} [start|stop|status]" >&2
    exit 2
    ;;
esac
