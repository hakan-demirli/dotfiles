#!/usr/bin/env bash
set -euo pipefail

if (($# == 0)); then
  echo "Usage: gtransfer.sh FILE..." >&2
  exit 2
fi

ABS_FILES=()
for file in "$@"; do
  ABS_FILES+=("$(realpath -- "$file")")
done

if ((${#ABS_FILES[@]} == 1)); then
  TRANSFER_LABEL=$(basename -- "${ABS_FILES[0]}")
else
  TRANSFER_LABEL="${#ABS_FILES[@]} items"
fi

transfer_file() {
  local src="$1"

  if [[ ${TERM:-} == *"kitty"* ]]; then
    if command -v kitten > /dev/null 2>&1; then
      kitten transfer "$src" ./Downloads/
      return 0
    else
      echo "TERM claims to be '${TERM:-}', but 'kitten' binary not found."
      echo "(Did you ssh with 'kitty +kitten ssh user@host'?)"
    fi
  fi

  if [[ ${TERM_PROGRAM:-} == "WezTerm" ]] || [[ ${TERM_PROGRAM:-} == "iTerm.app" ]] || [[ ${LC_TERMINAL:-} == "iTerm2" ]]; then
    if command -v base64 > /dev/null 2>&1; then
      local fn
      fn=$(basename "$src")
      printf "\033]1337;File=name=%s;size=%d:" "$(echo -n "$fn" | base64 | tr -d '\n')" "$(wc -c < "$src")"
      base64 < "$src" | tr -d '\n'
      printf "\a"
      return 0
    fi
  fi

  if command -v sz > /dev/null 2>&1; then
    sz --quiet "$src"
    return 0
  fi

  echo "Error: No suitable transfer method found."
  echo "  TERM: ${TERM:-}"
  echo "  TERM_PROGRAM: ${TERM_PROGRAM:-}"
  return 1
}

IS_REMOTE=0
if [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ] || [ -n "${SSH_CONNECTION:-}" ]; then
  IS_REMOTE=1
fi

MENU_ITEMS=()
if [ "$IS_REMOTE" -eq 1 ]; then
  MENU_ITEMS+=("back-home")
fi

LOCAL_HOST="${EMRE_HOME_HOST_ID:-$(hostname)}"
if [[ $LOCAL_HOST != laptop-1 ]] && command -v send-to-laptop > /dev/null 2>&1; then
  MENU_ITEMS+=("laptop-1-inbox")
fi

if [[ -r $HOME/.ssh/config ]]; then
  while IFS= read -r host; do
    MENU_ITEMS+=("$host")
  done < <(awk '$1 == "Host" { for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i }' "$HOME/.ssh/config")
fi

if command -v tailscale > /dev/null 2>&1 && command -v jq > /dev/null 2>&1; then
  while IFS= read -r peer; do
    [ -n "$peer" ] || continue
    MENU_ITEMS+=("$peer")
  done < <(
    tailscale status --json 2> /dev/null \
      | jq -r '(.Peer // {}) | .[] | select(.Online) | .DNSName | rtrimstr(".")' 2> /dev/null \
      || true
  )
fi

if ((${#MENU_ITEMS[@]} > 1)); then
  mapfile -t MENU_ITEMS < <(printf '%s\n' "${MENU_ITEMS[@]}" | awk '!seen[$0]++')
fi

if ((${#MENU_ITEMS[@]} == 0)); then
  echo "No transfer targets available." >&2
  exit 1
fi

TARGET=$(printf '%s\n' "${MENU_ITEMS[@]}" | fzf --layout=reverse --prompt="Transfer $TRANSFER_LABEL to > ") || exit 0

if [ -z "$TARGET" ]; then exit 0; fi

if [ "$TARGET" == "back-home" ]; then
  for file in "${ABS_FILES[@]}"; do
    transfer_file "$file"
  done
  exit 0
fi

if [ "$TARGET" == "laptop-1-inbox" ]; then
  exec send-to-laptop "${ABS_FILES[@]}"
fi

echo "Connecting to $TARGET..."
REMOTE_TMP="/tmp/yazi_cwd_$$"
ssh -t "$TARGET" "bash -lc 'yazi --cwd-file \"$REMOTE_TMP\"'"
Q_REMOTE_TMP=$(printf %q "$REMOTE_TMP")
# shellcheck disable=SC2029
REMOTE_DIR=$(ssh "$TARGET" "cat $Q_REMOTE_TMP && rm -f $Q_REMOTE_TMP")
REMOTE_DIR=$(echo "$REMOTE_DIR" | tr -d '\r\n')

if [ -z "$REMOTE_DIR" ]; then
  echo "Cancelled."
  exit 0
fi

echo "Transferring to $TARGET:$REMOTE_DIR/"
if ssh "$TARGET" "command -v rsync >/dev/null 2>&1"; then
  rsync -avP -- "${ABS_FILES[@]}" "$TARGET:$REMOTE_DIR/"
else
  scp -r -- "${ABS_FILES[@]}" "$TARGET:$REMOTE_DIR/"
fi
