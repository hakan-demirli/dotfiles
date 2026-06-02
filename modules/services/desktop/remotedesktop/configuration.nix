{
  flake.modules.nixos.services-remotedesktop =
    {
      config,
      pkgs,
      lib,
      inputs,
      ...
    }:
    let
      cfg = config.services.remotedesktop;
      common-packages = inputs.self.lib.mkPackages { inherit pkgs inputs; };

      # Default EDID: Samsung Q800T HDMI 2.1 (4K).
      # https://git.linuxtv.org/v4l-utils.git/plain/utils/edid-decode/data/samsung-q800t-hdmi2.1
      defaultEdidBase64 = "AP///////wBMLUBwAA4AAQEeAQOApV14Cqgzq1BFpScNSEi974BxT4HAgQCBgJUAqcCzANHACOgAMPJwWoCwWIoAUB10AAAeb8IAoKCgVVAwIDUAUB10AAAaAAAA/QAYeA//dwAKICAgICAgAAAA/ABTQU1TVU5HCiAgICAgAW4CA2fwXWEQHwQTBRQgISJdXl9gZWZiZD9AdXba28LDxMbHLAkHBxUHUFcHAGdUAIMBAADiAE/jBcMBbgMMAEAAmDwoAIABAgMEbdhdxAF4gFkCAADBNAvjBg0B5Q8B4PAf5QGLhJABb8IAoKCgVVAwIDUAUB10AAAaAAAAAAAAZw==";

      edidFirmware = pkgs.runCommand "remotedesktop-edid" { } ''
        mkdir -p $out/lib/firmware/edid
        echo '${cfg.edidBase64}' | ${pkgs.coreutils}/bin/base64 -d > $out/lib/firmware/edid/remotedesktop.bin
      '';
    in
    {
      options.services.remotedesktop = {
        enable = lib.mkEnableOption "remote desktop via Sunshine/Moonlight";

        headless = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether this is a headless host (no physical display).
            When true, a fake EDID monitor and managed Hyprland session
            will be configured for remote-only desktop access.
          '';
        };

        connector = lib.mkOption {
          type = lib.types.str;
          default = "DP-1";
          description = "DRM connector name for the fake EDID monitor (headless mode only).";
        };

        resolution = lib.mkOption {
          type = lib.types.str;
          default = "1920x1080@60";
          description = "Resolution for the fake EDID monitor (headless mode only).";
        };

        drmDevice = lib.mkOption {
          type = lib.types.str;
          default = "/dev/dri/card0";
          description = ''
            DRM device the headless Hyprland binds to (WLR_DRM_DEVICES).
            Override on multi-GPU hosts where the desired card isn't card0
            (e.g. /dev/dri/card1 for AMD when an Nvidia card claims card0).
          '';
        };

        edidBase64 = lib.mkOption {
          type = lib.types.str;
          default = defaultEdidBase64;
          description = ''
            Base64-encoded EDID blob injected at boot via
            drm.edid_firmware. Defaults to a Samsung Q800T 4K HDMI 2.1 panel.
            Override with `base64 -w0 /sys/class/drm/cardX-OUT/edid` from any
            real display whose modes you want the virtual monitor to advertise.
          '';
        };

      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            services.sunshine = {
              enable = true;
              autoStart = false;
              openFirewall = true;
              capSysAdmin = true;
            };

            systemd.services.sunshine-seed-creds = {
              description = "Seed Sunshine Web UI credentials";
              wantedBy = [ "multi-user.target" ];
              before = [ "sunshine.service" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                User = config.system.user.username;
                Group = "users";
              };
              script = ''
                ${pkgs.sunshine}/bin/sunshine --creds ${config.system.user.username} ${config.system.user.username}
              '';
            };

            environment.systemPackages =
              common-packages.remotedesktop-host
              ++ lib.optionals (!cfg.headless) common-packages.remotedesktop-client;
          }

          (lib.mkIf cfg.headless (
            let
              user = config.system.user.username;
              uid = toString config.system.user.uid;

              sunshineConfigFile = pkgs.writeText "sunshine.conf" ''
                capture = kms
                adapter_name = ${cfg.drmDevice}
                min_log_level = info
              '';

              sessionPath = lib.concatStringsSep ":" [
                "/run/wrappers/bin"
                "/home/${user}/.nix-profile/bin"
                "/etc/profiles/per-user/${user}/bin"
                "/nix/var/nix/profiles/default/bin"
                "/run/current-system/sw/bin"
                "/home/${user}/.local/bin"
              ];

              hyprlandHeadlessConf = pkgs.writeText "hyprland-headless.conf" ''
                monitor = ${cfg.connector},${cfg.resolution},0x0,1
                monitor = ,disable

                env = PATH,${sessionPath}
                env = XDG_RUNTIME_DIR,/run/user/${uid}
                env = XDG_SESSION_TYPE,wayland
                env = XDG_CURRENT_DESKTOP,Hyprland
                env = XDG_SESSION_DESKTOP,Hyprland
                env = MOZ_ENABLE_WAYLAND,1
                env = NIXOS_OZONE_WL,1

                input {
                    kb_layout = us
                    follow_mouse = 1
                    repeat_rate = 60
                    repeat_delay = 200
                }

                general {
                    border_size = 2
                    gaps_in = 3
                    gaps_out = 3
                    layout = dwindle
                }

                dwindle {
                    preserve_split = true
                }

                misc {
                    disable_hyprland_logo = true
                    mouse_move_enables_dpms = false
                    key_press_enables_dpms = false
                }

                $mainMod  = SUPER
                $launcher = pkill tofi || tofi-drun --drun-launch=true
                $locker   = hyprlock

                # Launcher: tap SUPER alone (release-style, mirrors the
                # lua `hl.bind("SUPER + SUPER_L", launcher, { release = true })`).
                bindr = SUPER, SUPER_L, exec, $launcher
                bindr = SUPER, SUPER_R, exec, $launcher

                # User shell-script launchers (~/.local/bin, picked up via PATH)
                bind = ALT,      N,      exec, todo_my
                bind = ALT,      Z,      exec, plan_my
                bind = $mainMod, M,      exec, player_my

                # Quick workspace jumps (laptop-style)
                bind = ALT, Tab,    workspace, previous
                bind = ALT, M,      workspace, 1
                bind = ALT, COMMA,  workspace, 2
                bind = ALT, PERIOD, workspace, 3
                bind = ALT, SLASH,  workspace, 4

                # Misc
                bind = $mainMod, B,   exec, pkill waybar || waybar
                bind = $mainMod, Tab, workspace, previous

                # Workspaces 1..9
                bind = $mainMod, 1, workspace, 1
                bind = $mainMod, 2, workspace, 2
                bind = $mainMod, 3, workspace, 3
                bind = $mainMod, 4, workspace, 4
                bind = $mainMod, 5, workspace, 5
                bind = $mainMod, 6, workspace, 6
                bind = $mainMod, 7, workspace, 7
                bind = $mainMod, 8, workspace, 8
                bind = $mainMod, 9, workspace, 9

                # Window focus
                bind = $mainMod, H, movefocus, l
                bind = $mainMod, J, movefocus, d
                bind = $mainMod, K, movefocus, u
                bind = $mainMod, L, movefocus, r

                # Window resize (repeating)
                binde = $mainMod CTRL, H, resizeactive, -20 0
                binde = $mainMod CTRL, J, resizeactive,  0 20
                binde = $mainMod CTRL, K, resizeactive,  0 -20
                binde = $mainMod CTRL, L, resizeactive,  20 0

                # Window actions
                bind = $mainMod, Q,      killactive
                bind = $mainMod, F,      fullscreen
                bind = $mainMod, escape, exec, $locker
                bind = $mainMod, S,      layoutmsg, togglesplit
                bind = $mainMod, E,      togglefloating
                bind = $mainMod, R,      pin

                # Screenshots
                bind = ,         Print, exec, pkill -9 wayscriber || wayscriber -a
                bind = $mainMod SHIFT, S, exec, pkill -9 wayscriber || wayscriber -a
                bind = $mainMod,       Y, exec, pkill -9 wayscriber || wayscriber -a

                # Exit Hyprland (remotedesktop.service will exit after, rd-start again to relaunch)
                bind = $mainMod CTRL, F4, exit

                # Move window to workspace
                bind = $mainMod CTRL, 1, movetoworkspace, 1
                bind = $mainMod CTRL, 2, movetoworkspace, 2
                bind = $mainMod CTRL, 3, movetoworkspace, 3
                bind = $mainMod CTRL, 4, movetoworkspace, 4
                bind = $mainMod CTRL, 5, movetoworkspace, 5
                bind = $mainMod CTRL, 6, movetoworkspace, 6
                bind = $mainMod CTRL, 7, movetoworkspace, 7
                bind = $mainMod CTRL, 8, movetoworkspace, 8
                bind = $mainMod CTRL, 9, movetoworkspace, 9
                bind = $mainMod CTRL, 0, movetoworkspace, 10

                # Mouse
                bindm = $mainMod, mouse:272, movewindow
                bindm = $mainMod, mouse:273, resizewindow
                bind  = $mainMod, mouse_down, workspace, e-1
                bind  = $mainMod, mouse_up,   workspace, e+1

                exec-once = ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd --all
              '';

              rdStartScript = pkgs.writeShellScript "remotedesktop-session" ''
                export XDG_RUNTIME_DIR="/run/user/${uid}"
                export WLR_BACKENDS=drm
                export WLR_DRM_DEVICES=${cfg.drmDevice}
                export XDG_SESSION_TYPE=wayland
                export PULSE_SERVER=unix:$XDG_RUNTIME_DIR/pulse/native
                export PULSE_COOKIE=$HOME/.config/pulse/cookie
                export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus

                cleanup() {
                  kill $SUN_PID $HYPR_PID 2>/dev/null || true
                  wait $SUN_PID $HYPR_PID 2>/dev/null || true
                }
                trap cleanup EXIT TERM INT

                ${pkgs.hyprland}/bin/Hyprland -c ${hyprlandHeadlessConf} &
                HYPR_PID=$!

                for i in $(seq 1 30); do
                  if ls "$XDG_RUNTIME_DIR/hypr/"*"/.socket.sock" &>/dev/null; then
                    break
                  fi
                  sleep 0.5
                done
                sleep 1

                export WAYLAND_DISPLAY=$(ls "$XDG_RUNTIME_DIR/wayland-"* 2>/dev/null | head -1 | xargs basename || echo "wayland-1")

                ${config.security.wrapperDir}/sunshine &
                SUN_PID=$!

                wait $HYPR_PID
              '';
            in
            {
              hardware.firmware = [ edidFirmware ];
              boot.kernelParams = [
                "drm.edid_firmware=${cfg.connector}:edid/remotedesktop.bin"
                "video=${cfg.connector}:e"
              ];

              programs.hyprland.enable = true;
              systemd.defaultUnit = lib.mkForce "multi-user.target";
              environment.systemPackages = with pkgs; [
                kitty
                foot
              ];

              services.seatd.enable = true;
              users.users.${user}.extraGroups = [ "seat" ];

              systemd.services.seatd.serviceConfig.Type = lib.mkForce "exec";

              systemd.services.sunshine-write-conf = {
                description = "Provision default sunshine.conf for KMS capture";
                wantedBy = [ "multi-user.target" ];
                before = [ "sunshine.service" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  User = user;
                  Group = "users";
                };
                script = ''
                  confdir="$HOME/.config/sunshine"
                  mkdir -p "$confdir"
                  if [ ! -s "$confdir/sunshine.conf" ]; then
                    install -m 0644 ${sunshineConfigFile} "$confdir/sunshine.conf"
                  fi
                '';
              };

              systemd.services.remotedesktop = {
                description = "Headless Hyprland + Sunshine remote desktop session";
                after = [ "seatd.service" ];
                requires = [ "seatd.service" ];
                serviceConfig = {
                  Type = "simple";
                  User = user;
                  Group = "users";
                  SupplementaryGroups = [
                    "video"
                    "render"
                    "input"
                    "seat"
                  ];
                  PAMName = "login";
                  ExecStart = rdStartScript;
                  Restart = "no";
                  KillMode = "control-group";
                  KillSignal = "SIGTERM";
                  TimeoutStopSec = 10;
                };
                wantedBy = [ ];
              };

              security.sudo.extraRules = [
                {
                  users = [ user ];
                  commands = [
                    {
                      command = "/run/current-system/sw/bin/systemctl start remotedesktop";
                      options = [ "NOPASSWD" ];
                    }
                    {
                      command = "/run/current-system/sw/bin/systemctl stop remotedesktop";
                      options = [ "NOPASSWD" ];
                    }
                    {
                      command = "/run/current-system/sw/bin/systemctl is-active remotedesktop";
                      options = [ "NOPASSWD" ];
                    }
                    {
                      command = "/run/current-system/sw/bin/systemctl is-active --quiet remotedesktop";
                      options = [ "NOPASSWD" ];
                    }
                    {
                      command = "/run/current-system/sw/bin/systemctl cat remotedesktop";
                      options = [ "NOPASSWD" ];
                    }
                  ];
                }
              ];
            }
          ))
        ]
      );
    };
}
