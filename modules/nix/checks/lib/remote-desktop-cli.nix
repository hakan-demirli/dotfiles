{
  pkgs,
  self,
}:
let
  cli = self + /modules/services/remotedesktop-cli.sh;
  rdPackage = pkgs.runCommand "remote-desktop-cli" { } ''
    mkdir -p "$out/bin"
    install -m 0755 ${cli} "$out/bin/rd.sh"
    patchShebangs "$out/bin"
  '';
  mockSystemctl = pkgs.writeShellScriptBin "systemctl" ''
    printf '%s\n' "$*" >> "$MOCK_STATE/calls"
    case "$*" in
      "is-active --quiet remotedesktop") test -e "$MOCK_STATE/headless" ;;
      "--user is-active --quiet sunshine") test -e "$MOCK_STATE/sunshine" ;;
      "--user is-active --quiet graphical-session.target") test -e "$MOCK_STATE/graphical" ;;
      "cat remotedesktop") test -e "$MOCK_STATE/headless-available" ;;
      "start remotedesktop") touch "$MOCK_STATE/headless" ;;
      "--user start sunshine") touch "$MOCK_STATE/sunshine" ;;
      "stop remotedesktop") rm -f "$MOCK_STATE/headless" ;;
      "--user stop sunshine") rm -f "$MOCK_STATE/sunshine" ;;
      *) exit 2 ;;
    esac
  '';
  mockSudo = pkgs.writeShellScriptBin "sudo" ''
    if [[ ''${1:-} == -n ]]; then
      shift
    fi
    exec "$@"
  '';
  mockTailscale = pkgs.writeShellScriptBin "tailscale" ''
    case "''${1:-}" in
      ip) printf '%s\n' 100.64.0.9 ;;
      status) printf '%s\n' '100.64.0.9 test-host.ts.example.test linux -' ;;
      *) exit 2 ;;
    esac
  '';
  mockSleep = pkgs.writeShellScriptBin "sleep" ''
    exit 0
  '';
in
pkgs.runCommand "remote-desktop-cli"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.gawk
      mockSleep
      mockSudo
      mockSystemctl
      mockTailscale
      rdPackage
    ];
  }
  ''
    export MOCK_STATE="$TMPDIR/state"
    mkdir -p "$MOCK_STATE"

    SYSTEMCTL=systemctl SUDO=sudo rd.sh status > "$TMPDIR/status-stopped"
    grep -qx 'Remote desktop: STOPPED' "$TMPDIR/status-stopped"
    grep -qx 'Moonlight target: test-host.ts.example.test' "$TMPDIR/status-stopped"
    grep -qx 'Moonlight IP:     100.64.0.9' "$TMPDIR/status-stopped"

    touch "$MOCK_STATE/graphical"
    SYSTEMCTL=systemctl SUDO=sudo rd.sh start > "$TMPDIR/start-desktop"
    test -e "$MOCK_STATE/sunshine"
    grep -qx 'Graphical session detected. Starting Sunshine for current display...' "$TMPDIR/start-desktop"

    SYSTEMCTL=systemctl SUDO=sudo rd.sh stop > "$TMPDIR/stop-desktop"
    test ! -e "$MOCK_STATE/sunshine"
    grep -qx 'Stopping Sunshine...' "$TMPDIR/stop-desktop"

    rm -f "$MOCK_STATE/graphical"
    touch "$MOCK_STATE/headless-available"
    SYSTEMCTL=systemctl SUDO=sudo rd.sh start > "$TMPDIR/start-headless"
    test -e "$MOCK_STATE/headless"
    grep -qx 'No graphical session. Starting headless Hyprland + Sunshine...' "$TMPDIR/start-headless"

    SYSTEMCTL=systemctl SUDO=sudo rd.sh stop > "$TMPDIR/stop-headless"
    test ! -e "$MOCK_STATE/headless"
    grep -qx 'Stopping headless remote desktop...' "$TMPDIR/stop-headless"

    touch "$out"
  ''
