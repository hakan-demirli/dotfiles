#!/usr/bin/env bash

set -euo pipefail

UNIT="caffeinate.service"
UNIT_NAME="${UNIT%.service}"
WHY="SwayNC caffeinate toggle"
WHAT="idle:sleep:handle-lid-switch"

SYSTEMCTL="/run/current-system/sw/bin/systemctl"
SYSTEMD_RUN="/run/current-system/sw/bin/systemd-run"
SYSTEMD_INHIBIT="/run/current-system/sw/bin/systemd-inhibit"
SLEEP="/run/current-system/sw/bin/sleep"

notify() {
  command -v notify-send > /dev/null 2>&1 || return 0
  notify-send -a caffeinate -t 2000 \
    -h string:x-canonical-private-synchronous:caffeinate \
    "$1" "${2:-}" 2> /dev/null || true
}

is_active() {
  "$SYSTEMCTL" --user is-active --quiet "$UNIT"
}

has_inhibitor() {
  local inhibitors
  inhibitors="$($SYSTEMD_INHIBIT --list --no-pager 2> /dev/null || true)"
  [[ $inhibitors == *"Caffeinate"* ]] \
    && [[ $inhibitors == *"$WHY"* ]] \
    && [[ $inhibitors == *"handle-lid-switch"* ]] \
    && [[ $inhibitors == *"block"* ]]
}

wait_active() {
  local _
  for _ in {1..20}; do
    is_active && return 0
    "$SLEEP" 0.05
  done
  return 1
}

wait_inhibitor() {
  local _
  for _ in {1..20}; do
    has_inhibitor && return 0
    "$SLEEP" 0.05
  done
  return 1
}

start() {
  if is_active; then
    return 0
  fi

  "$SYSTEMCTL" --user reset-failed "$UNIT" > /dev/null 2>&1 || true
  "$SYSTEMD_RUN" \
    --user \
    --unit="$UNIT_NAME" \
    --collect \
    --description="SwayNC caffeinate inhibitor" \
    "$SYSTEMD_INHIBIT" \
    --who="Caffeinate" \
    --what="$WHAT" \
    --mode=block \
    --why="$WHY" \
    "$SLEEP" infinity > /dev/null

  if ! wait_active; then
    "$SYSTEMCTL" --user status "$UNIT" --no-pager >&2 || true
    notify "Caffeinate failed" "Could not start idle/sleep/lid inhibitor"
    return 1
  fi

  if ! wait_inhibitor; then
    "$SYSTEMCTL" --user status "$UNIT" --no-pager >&2 || true
    "$SYSTEMD_INHIBIT" --list --no-pager >&2 || true
    notify "Caffeinate failed" "Service started, but logind did not show the inhibitor"
    return 1
  fi

  notify "Caffeinate enabled" "Idle, sleep, and lid suspend are blocked"
}

stop() {
  "$SYSTEMCTL" --user stop "$UNIT" > /dev/null 2>&1 || true
  "$SYSTEMCTL" --user reset-failed "$UNIT" > /dev/null 2>&1 || true
  notify "Caffeinate disabled" "Normal idle and lid behavior restored"
}

status() {
  if is_active && has_inhibitor; then
    printf 'true\n'
  else
    printf 'false\n'
  fi
}

toggle() {
  if is_active; then
    stop
  else
    start
  fi
}

from_toggle_state() {
  case "${SWAYNC_TOGGLE_STATE:-}" in
    true | TRUE | 1)
      start
      ;;
    false | FALSE | 0)
      stop
      ;;
    *)
      printf 'SWAYNC_TOGGLE_STATE must be true or false, got [%s]\n' "${SWAYNC_TOGGLE_STATE:-}" >&2
      return 2
      ;;
  esac
}

case "${1:-toggle}" in
  true | TRUE | 1)
    start
    ;;
  false | FALSE | 0)
    stop
    ;;
  swaync)
    from_toggle_state
    ;;
  on | start | enable)
    start
    ;;
  off | stop | disable | restore)
    stop
    ;;
  status | active)
    status
    ;;
  list)
    "$SYSTEMD_INHIBIT" --list --no-pager
    ;;
  toggle)
    toggle
    ;;
  *)
    printf 'Usage: %s [toggle|on|off|status|list|swaync|true|false]\n' "$0" >&2
    exit 2
    ;;
esac
