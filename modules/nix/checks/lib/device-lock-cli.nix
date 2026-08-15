{
  pkgs,
  self,
}:
let
  bin = self + /modules/home/common/pkgs/bin;
  lockPackage = pkgs.runCommand "device-lock-cli" { } ''
    mkdir -p "$out/bin"
    install -m 0755 ${bin}/device-lock-toggle.sh "$out/bin/device-lock-toggle.sh"
    install -m 0755 ${bin}/rotation-lock-toggle.sh "$out/bin/rotation-lock-toggle.sh"
    install -m 0755 ${bin}/tablet-lock-toggle.sh "$out/bin/tablet-lock-toggle.sh"
    patchShebangs "$out/bin"
  '';
  mockPgrep = pkgs.writeShellScriptBin "pgrep" ''
    case "$*" in
      *orientation_watcher.py*) test -e "$MOCK_STATE/orientation-watcher" ;;
      *tablet_mode_watcher.py*) test -e "$MOCK_STATE/tablet-watcher" ;;
      *) exit 1 ;;
    esac
  '';
  mockPkill = pkgs.writeShellScriptBin "pkill" ''
    printf '%s\n' "$*" >> "$MOCK_STATE/signals"
    case "$*" in
      *USR1*orientation_watcher.py*) printf 0 > "$XDG_RUNTIME_DIR/orientation_lock" ;;
    esac
  '';
  mockNotify = pkgs.writeShellScriptBin "notify-send" ''
    printf '%s\n' "$*" >> "$MOCK_STATE/notifications"
  '';
in
pkgs.runCommand "device-lock-cli"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      lockPackage
      mockNotify
      mockPgrep
      mockPkill
    ];
  }
  ''
    export MOCK_STATE="$TMPDIR/mock"
    export XDG_RUNTIME_DIR="$TMPDIR/runtime"
    mkdir -p "$MOCK_STATE" "$XDG_RUNTIME_DIR"

    test "$(rotation-lock-toggle.sh status)" = false
    rotation-lock-toggle.sh on
    test "$(cat "$XDG_RUNTIME_DIR/orientation_lock")" = 1
    test "$(rotation-lock-toggle.sh status)" = true
    grep -q 'Rotation locked.*Screen will not auto-rotate' "$MOCK_STATE/notifications"

    touch "$MOCK_STATE/orientation-watcher"
    rotation-lock-toggle.sh off
    test "$(cat "$XDG_RUNTIME_DIR/orientation_lock")" = 0
    grep -qx -- '-USR1 -f orientation_watcher.py' "$MOCK_STATE/signals"
    grep -q 'Rotation unlocked.*Auto-rotate restored' "$MOCK_STATE/notifications"

    test "$(tablet-lock-toggle.sh status)" = false
    SWAYNC_TOGGLE_STATE=true tablet-lock-toggle.sh swaync
    test "$(cat "$XDG_RUNTIME_DIR/tablet_mode_lock")" = 1
    test "$(tablet-lock-toggle.sh status)" = true
    touch "$MOCK_STATE/tablet-watcher"
    SWAYNC_TOGGLE_STATE=false tablet-lock-toggle.sh swaync
    test "$(cat "$XDG_RUNTIME_DIR/tablet_mode_lock")" = 0
    grep -qx -- '-USR2 -f tablet_mode_watcher.py' "$MOCK_STATE/signals"
    grep -q 'Tablet mode locked.*Hinge events will be ignored' "$MOCK_STATE/notifications"
    grep -q 'Tablet mode unlocked.*Hinge events will be honored again' "$MOCK_STATE/notifications"

    if SWAYNC_TOGGLE_STATE=invalid tablet-lock-toggle.sh swaync; then
      exit 1
    fi

    touch "$out"
  ''
