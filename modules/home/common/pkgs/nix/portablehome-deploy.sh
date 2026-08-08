#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << USAGE >&2
usage: $(basename "$0") [--dry-run] [--no-bashrc] user@host

  --dry-run     Show what would change, do nothing.
  --no-bashrc   Skip touching ~/.bashrc on the remote.
USAGE
}

DRY_RUN=0
TOUCH_BASHRC=1
DEST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-bashrc)
      TOUCH_BASHRC=0
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      echo "portablehome-deploy: unknown flag: $1" >&2
      usage
      exit 2
      ;;
    *)
      if [ -n "$DEST" ]; then
        echo "portablehome-deploy: extra arg: $1" >&2
        exit 2
      fi
      DEST="$1"
      shift
      ;;
  esac
done

if [ -z "$DEST" ]; then
  usage
  exit 2
fi

SRC_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for sub in bin scripts config; do
  if [ ! -d "$SRC_ROOT/$sub" ]; then
    echo "portablehome-deploy: expected $SRC_ROOT/$sub to exist" >&2
    exit 3
  fi
done

TS="$(date +%Y%m%d-%H%M%S)"

log() { printf '[deploy] %s\n' "$*"; }

log "preflight: ssh $DEST"
ssh -o BatchMode=yes -o ConnectTimeout=10 "$DEST" true

RSYNC_COMMON=(--archive --compress --human-readable)
if [ "$DRY_RUN" -eq 1 ]; then
  RSYNC_COMMON+=(--dry-run --itemize-changes)
  log "DRY-RUN MODE: no changes will be applied"
fi

log "bin/ -> $DEST:~/.local/bin/mybin/  (backup + --delete)"
if [ "$DRY_RUN" -eq 0 ]; then
  ssh "$DEST" "mkdir -p ~/.local/bin"
  # shellcheck disable=SC2029
  ssh "$DEST" "test -d ~/.local/bin/mybin && mv ~/.local/bin/mybin ~/.local/bin/mybin-$TS || true"
fi
rsync "${RSYNC_COMMON[@]}" --delete "$SRC_ROOT/bin/" "$DEST:.local/bin/mybin/"

log "scripts/ -> $DEST:~/.local/bin/myscripts/  (backup + --delete)"
if [ "$DRY_RUN" -eq 0 ]; then
  # shellcheck disable=SC2029
  ssh "$DEST" "test -d ~/.local/bin/myscripts && mv ~/.local/bin/myscripts ~/.local/bin/myscripts-$TS || true"
fi
rsync "${RSYNC_COMMON[@]}" --delete "$SRC_ROOT/scripts/" "$DEST:.local/bin/myscripts/"

log "config/ -> $DEST:~/.config/  (no --delete, per-file .orig-$TS backup on collision)"
if [ "$DRY_RUN" -eq 0 ]; then
  ssh "$DEST" "mkdir -p ~/.config"
fi
rsync "${RSYNC_COMMON[@]}" --backup --suffix=".orig-$TS" "$SRC_ROOT/config/" "$DEST:.config/"

if [ "$TOUCH_BASHRC" -eq 1 ]; then
  log "bashrc: adding marker block if absent"
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  (dry-run) would append marker block to $DEST:~/.bashrc if absent"
  else
    ssh "$DEST" 'bash -s' << 'REMOTE_EOF'
set -euo pipefail
BASHRC="$HOME/.bashrc"
BEGIN="# >>> dotfiles-portable >>>"
BLOCK='# >>> dotfiles-portable >>>
export PATH="$HOME/.local/bin/myscripts:$HOME/.local/bin/mybin:$PATH"
if [ -f "$HOME/.config/bash/main.sh" ]; then
  . "$HOME/.config/bash/main.sh"
fi
# <<< dotfiles-portable <<<'
touch "$BASHRC"
if grep -qF "$BEGIN" "$BASHRC"; then
  echo "[deploy-remote] $BASHRC already has dotfiles-portable block. Leaving it alone"
else
  printf '\n%s\n' "$BLOCK" >> "$BASHRC"
  echo "[deploy-remote] appended dotfiles-portable block to $BASHRC"
fi
REMOTE_EOF
  fi
else
  log "bashrc: skipped (--no-bashrc)"
fi

log "done."
if [ "$DRY_RUN" -eq 1 ]; then
  log "(dry-run) rerun without --dry-run to apply."
fi
