{ pkgs }:
let
  inherit (pkgs) lib;
  ps = pkgs.pkgsStatic;

  staticBins = [
    ps.ripgrep
    ps.fd
    ps.bat
    ps.fzf
    ps.jq
    ps.tree
    ps.delta
    ps.starship
    ps.htop
    ps.tmux
    ps.yek
    ps.ouch
    ps.p7zip
    ps.unzip
    ps.wget
    ps.zip
  ];

  scriptsSrc = ../bin;
  configSrc = ../../config;

  deployScript = pkgs.writeTextFile {
    name = "portablehome-deploy.sh";
    executable = true;
    text = ''
      #!/usr/bin/env bash
      #
      # portablehome deploy.sh
      #
      # Semantics:
      #   bin/     -> ~/.local/bin/mybin/      static bins   (backup + --delete)
      #   scripts/ -> ~/.local/bin/myscripts/  shell wrappers (backup + --delete)
      #   config/  -> ~/.config/               no --delete; per-file .orig-<ts> backup
      #   bashrc                               idempotent marker block

      set -euo pipefail

      usage() {
        cat <<USAGE
      usage: $(basename "$0") [--dry-run] [--no-bashrc] user@host

        Ship the portablehome payload to a nix-less linux host.

        --dry-run     Show what would change, do nothing.
        --no-bashrc   Skip touching ~/.bashrc on the remote.
        -h, --help    This.
      USAGE
      }

      DRY_RUN=0
      TOUCH_BASHRC=1
      DEST=""

      while [ $# -gt 0 ]; do
        case "$1" in
          --dry-run)   DRY_RUN=1; shift ;;
          --no-bashrc) TOUCH_BASHRC=0; shift ;;
          -h|--help)   usage; exit 0 ;;
          -*)          echo "unknown flag: $1" >&2; usage; exit 2 ;;
          *)           if [ -n "$DEST" ]; then echo "extra arg: $1" >&2; exit 2; fi
                       DEST="$1"; shift ;;
        esac
      done

      if [ -z "$DEST" ]; then
        usage
        exit 2
      fi

      SRC_ROOT="$(cd -- "$(dirname -- "''${BASH_SOURCE[0]}")" && pwd)"

      for sub in bin scripts config; do
        if [ ! -d "$SRC_ROOT/$sub" ]; then
          echo "error: expected $SRC_ROOT/$sub to exist. Is the payload complete?" >&2
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
        ssh "$DEST" "test -d ~/.local/bin/mybin && mv ~/.local/bin/mybin ~/.local/bin/mybin-$TS || true"
      fi
      rsync "''${RSYNC_COMMON[@]}" --delete "$SRC_ROOT/bin/" "$DEST:.local/bin/mybin/"

      log "scripts/ -> $DEST:~/.local/bin/myscripts/  (backup + --delete)"
      if [ "$DRY_RUN" -eq 0 ]; then
        ssh "$DEST" "test -d ~/.local/bin/myscripts && mv ~/.local/bin/myscripts ~/.local/bin/myscripts-$TS || true"
      fi
      rsync "''${RSYNC_COMMON[@]}" --delete "$SRC_ROOT/scripts/" "$DEST:.local/bin/myscripts/"

      log "config/ -> $DEST:~/.config/  (no --delete, per-file .orig-$TS backup on collision)"
      if [ "$DRY_RUN" -eq 0 ]; then
        ssh "$DEST" "mkdir -p ~/.config"
      fi
      rsync "''${RSYNC_COMMON[@]}" --backup --suffix=".orig-$TS" "$SRC_ROOT/config/" "$DEST:.config/"

      if [ "$TOUCH_BASHRC" -eq 1 ]; then
        log "bashrc: adding marker block if absent"
        if [ "$DRY_RUN" -eq 1 ]; then
          log "  (dry-run) would append marker block to $DEST:~/.bashrc if not already present"
        else
          ssh "$DEST" 'bash -s' <<'REMOTE_EOF'
      set -euo pipefail
      BASHRC="$HOME/.bashrc"
      BEGIN="# >>> dotfiles-portable >>>"
      BLOCK='# >>> dotfiles-portable >>>
      # Managed by portablehome deploy.sh. Delete the whole block (BEGIN..END)
      # to unmanage; deploy re-adds it on next run.
      export PATH="$HOME/.local/bin/myscripts:$HOME/.local/bin/mybin:$PATH"
      if [ -f "$HOME/.config/bash/main.sh" ]; then
        # shellcheck source=/dev/null
        . "$HOME/.config/bash/main.sh"
      fi
      # <<< dotfiles-portable <<<'
      touch "$BASHRC"
      if grep -qF "$BEGIN" "$BASHRC"; then
        echo "[deploy-remote] $BASHRC already has dotfiles-portable block; leaving alone"
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
    '';
  };
in
pkgs.runCommand "portablehome"
  {
    passthru = {
      inherit staticBins;
      binNames = map (p: p.pname or p.name) staticBins;
    };
    meta = {
      description = "Portable dotfiles bundle for nix-less linux hosts.";
      platforms = lib.platforms.linux;
    };
  }
  ''
    mkdir -p $out/bin $out/scripts $out/config

    ${lib.concatMapStringsSep "\n" (p: ''
      if [ -d ${p}/bin ]; then
        for f in ${p}/bin/*; do
          bn="$(basename "$f")"
          if [ ! -e "$out/bin/$bn" ]; then
            cp -a "$f" "$out/bin/$bn"
          else
            echo "portablehome: skipping duplicate $bn from ${p.pname or p.name}"
          fi
        done
      fi
    '') staticBins}

    cp -a ${scriptsSrc}/. $out/scripts/
    chmod -R u+w $out/scripts
    find $out/scripts -type f -exec chmod a+rx {} +

    cp -a ${configSrc}/. $out/config/
    chmod -R u+w $out/config

    cp ${deployScript} $out/deploy.sh
    chmod +x $out/deploy.sh
  ''
