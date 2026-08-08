{
  config,
  lib,
  pkgs,
  host ? null,
  cluster ? null,
  ...
}:
let
  cfg = config.services.remotedesktop;
  sunshineLabel = if host == null then "false" else (host.labels.sunshine or "false");
  effectiveMode = if cfg.modeOverride != null then cfg.modeOverride else sunshineLabel;
  headless = effectiveMode == "headless";

  owner = if host == null then null else (host.ownership.owner or null);
  ownerUser = if owner == null || cluster == null then null else (cluster.users.${owner} or null);
  primaryAccount = if ownerUser == null then null else ownerUser.system_account;
  user = if primaryAccount == null then "REMOTEDESKTOP_USER_UNSET" else primaryAccount.username;
  uid = toString (if primaryAccount == null then 1000 else primaryAccount.uid);

  hyprlandConfPath = "/home/${user}/.config/hypr/headless.conf";

  rdStartScript = pkgs.writeShellScript "remotedesktop-personal-session" ''
    set -u
    export XDG_RUNTIME_DIR="/run/user/${uid}"
    export WLR_BACKENDS=drm
    export WLR_DRM_DEVICES=${cfg.drmDevice}
    export XDG_SESSION_TYPE=wayland
    export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native
    export PULSE_COOKIE=$HOME/.config/pulse/cookie
    export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

    if [ ! -r ${hyprlandConfPath} ]; then
      echo "remotedesktop-session: missing ${hyprlandConfPath}" >&2
      exit 1
    fi

    cleanup() {
      kill $SUN_PID $HYPR_PID 2>/dev/null || true
      wait $SUN_PID $HYPR_PID 2>/dev/null || true
    }
    trap cleanup EXIT TERM INT

    ${pkgs.hyprland}/bin/Hyprland -c ${hyprlandConfPath} &
    HYPR_PID=$!

    for _ in $(seq 1 30); do
      if ls "$XDG_RUNTIME_DIR/hypr/"*"/.socket.sock" >/dev/null 2>&1; then
        break
      fi
      sleep 0.5
    done
    sleep 1

    WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR/wayland-"* 2>/dev/null | head -1 | xargs -r basename || echo "wayland-1")
    export WAYLAND_DISPLAY

    ${config.security.wrapperDir}/sunshine &
    SUN_PID=$!

    wait $HYPR_PID
  '';
in
{
  config = lib.mkIf headless {
    programs.hyprland.enable = true;

    environment.systemPackages = with pkgs; [
      kitty
      foot
    ];

    services.remotedesktop.sessionExecStart = rdStartScript;
  };
}
