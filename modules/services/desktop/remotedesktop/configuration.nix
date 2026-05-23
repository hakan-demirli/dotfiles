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

      # Samsung Q800T HDMI 2.1 EDID
      # https://git.linuxtv.org/v4l-utils.git/plain/utils/edid-decode/data/samsung-q800t-hdmi2.1
      edidBase64 = "AP///////wBMLUBwAA4AAQEeAQOApV14Cqgzq1BFpScNSEi974BxT4HAgQCBgJUAqcCzANHACOgAMPJwWoCwWIoAUB10AAAeb8IAoKCgVVAwIDUAUB10AAAaAAAA/QAYeA//dwAKICAgICAgAAAA/ABTQU1TVU5HCiAgICAgAW4CA2fwXWEQHwQTBRQgISJdXl9gZWZiZD9AdXba28LDxMbHLAkHBxUHUFcHAGdUAIMBAADiAE/jBcMBbgMMAEAAmDwoAIABAgMEbdhdxAF4gFkCAADBNAvjBg0B5Q8B4PAf5QGLhJABb8IAoKCgVVAwIDUAUB10AAAaAAAAAAAAZw==";

      edidFirmware = pkgs.runCommand "remotedesktop-edid" { } ''
        mkdir -p $out/lib/firmware/edid
        echo '${edidBase64}' | ${pkgs.coreutils}/bin/base64 -d > $out/lib/firmware/edid/remotedesktop.bin
      '';

      hyprlandHeadlessConf = pkgs.writeText "hyprland-headless.conf" ''
        monitor = ${cfg.connector},${cfg.resolution},0x0,1
        monitor = ,disable

        input {
            kb_layout = us
            follow_mouse = 1
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

        $mainMod = SUPER
        bind = $mainMod, Q, killactive
        bind = $mainMod, F, fullscreen
        bind = $mainMod, E, togglefloating
        bind = $mainMod, H, movefocus, l
        bind = $mainMod, J, movefocus, d
        bind = $mainMod, K, movefocus, u
        bind = $mainMod, L, movefocus, r
        bind = $mainMod, 1, workspace, 1
        bind = $mainMod, 2, workspace, 2
        bind = $mainMod, 3, workspace, 3
        bind = $mainMod, 4, workspace, 4
        bind = $mainMod CTRL, 1, movetoworkspace, 1
        bind = $mainMod CTRL, 2, movetoworkspace, 2
        bind = $mainMod CTRL, 3, movetoworkspace, 3
        bind = $mainMod CTRL, 4, movetoworkspace, 4
        bind = $mainMod, Return, exec, kitty

        exec-once = dbus-update-activation-environment --systemd --all
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

      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            services.sunshine = {
              enable = true;
              autoStart = false;
              openFirewall = false;
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

              rdStartScript = pkgs.writeShellScript "remotedesktop-session" ''
                export XDG_RUNTIME_DIR="/run/user/${uid}"
                export WLR_BACKENDS=drm
                export WLR_DRM_DEVICES=/dev/dri/card0
                export XDG_SESSION_TYPE=wayland

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
