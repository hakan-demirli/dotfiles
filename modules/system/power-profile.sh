#!/usr/bin/env bash
set -u
set -o pipefail

BACKEND=${POWER_PROFILE_BACKEND:?internal error: POWER_PROFILE_BACKEND unset}
LOCK_FILE=/run/power-profile/lock
STATE_FILE=/run/power-profile/state
SUDO=/run/wrappers/bin/sudo

need_root() {
  local self
  [ "$(id -u)" -eq 0 ] && return 0
  self=$(readlink -f "$0") || exit 1
  [ -x "$SUDO" ] || {
    echo "sudo wrapper not found at $SUDO" >&2
    exit 1
  }
  exec "$SUDO" -- "$self" "$@"
}

acquire_lock() {
  mkdir -p "${LOCK_FILE%/*}"
  exec 9> "$LOCK_FILE"
  flock -x 9
}

publish_state() {
  local mode=$1 staged
  staged=$(mktemp "${STATE_FILE%/*}/.state.XXXXXX") || return 1
  if ! printf '%s\n' "$mode" > "$staged" || ! chmod 0644 "$staged" || ! mv -f "$staged" "$STATE_FILE"; then
    rm -f "$staged"
    return 1
  fi
}

read_applied_mode() {
  local mode
  if [ -r "$STATE_FILE" ] && IFS= read -r mode < "$STATE_FILE"; then
    case "$mode" in
      turbo | balanced | silent)
        printf '%s' "$mode"
        return 0
        ;;
    esac
  fi
  printf '%s' unknown
}

mode_label() {
  case "$1" in
    turbo) printf '%s' Turbo ;;
    balanced) printf '%s' Balanced ;;
    silent) printf '%s' Silent ;;
    *) printf '%s' Unknown ;;
  esac
}

print_status() {
  echo "Last applied profile : $(read_applied_mode)"
  "$BACKEND" status
}

cmd_json() {
  local mode rpm
  mode=$(read_applied_mode)
  if ! rpm=$("$BACKEND" rpm 2> /dev/null) || [[ ! $rpm =~ ^[0-9]+$ ]]; then
    rpm=unknown
  fi
  printf '{"text":"󰈐","class":"%s","tooltip":"Power profile: %s\\nFan: %s RPM"}\n' \
    "$mode" "$(mode_label "$mode")" "$rpm"
}

cmd_status() {
  need_root status
  acquire_lock
  print_status
}

cmd_apply() {
  local mode=$1 rc=0
  need_root "$mode"
  acquire_lock
  logger -t power-profile -- "applying $mode (caller=${SUDO_USER:-root})" || true
  "$BACKEND" apply "$mode" || rc=$?
  if [ "$rc" -ne 0 ]; then
    logger -t power-profile -- "failed $mode" || true
    echo "Profile application failed. State was not updated." >&2
    return "$rc"
  fi
  publish_state "$mode" || {
    logger -t power-profile -- "applied $mode but failed to publish state" || true
    echo "Profile applied but failed to publish state." >&2
    return 1
  }
  logger -t power-profile -- "applied $mode" || true
  echo
  print_status
}

is_board_command() {
  local name
  while IFS= read -r name; do
    [ "$name" = "$1" ] && return 0
  done < <("$BACKEND" commands)
  return 1
}

cmd_board() {
  if ! is_board_command "$1"; then
    echo "unknown subcommand: $1" >&2
    cmd_help >&2
    exit 2
  fi
  need_root "$@"
  acquire_lock
  exec "$BACKEND" run "$@"
}

cmd_help() {
  cat << 'EOF'
usage: power-profile {status|json|turbo|balanced|silent|help|BOARD COMMAND}

Manual override. No daemons, no auto. What you set stays set until next call or reset.

  status     [sudo]   last applied profile and board state
  json                last applied profile and fan rpm as waybar JSON
  turbo      [sudo]   maximum performance and cooling
  balanced   [sudo]   board trade-off between turbo and silent
  silent     [sudo]   minimum noise and power
  help                this

EOF
  "$BACKEND" help
}

case "${1:-status}" in
  status) cmd_status ;;
  json) cmd_json ;;
  turbo | t) cmd_apply turbo ;;
  balanced | b) cmd_apply balanced ;;
  silent | s) cmd_apply silent ;;
  help | -h | --help) cmd_help ;;
  *) cmd_board "$@" ;;
esac
