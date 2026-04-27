{
  flake = {
    modules = {
      nixos.system-hibernation =
        { pkgs, ... }:
        {
          systemd.sleep.settings.Sleep = {
            HibernateMode = "shutdown";
            HibernateState = "disk";
            HibernateDelaySec = "30min";
          };

          boot.kernelParams = [
            "no_console_suspend"
            "pm_debug_messages"
          ];

          services.journald.extraConfig = ''
            Storage=persistent
            SystemMaxUse=2G
            RuntimeMaxUse=200M
          '';

          systemd.services.resume-debug = {
            description = "Capture diagnostics after resume from sleep/hibernate";
            after = [
              "suspend.target"
              "hibernate.target"
              "hybrid-sleep.target"
              "suspend-then-hibernate.target"
            ];
            wantedBy = [
              "suspend.target"
              "hibernate.target"
              "hybrid-sleep.target"
              "suspend-then-hibernate.target"
            ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = pkgs.writeShellScript "resume-debug" ''
                set -u
                TS=$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S)
                DIR=/var/log/resume-debug/$TS
                ${pkgs.coreutils}/bin/mkdir -p "$DIR"

                {
                  echo "=== resume-debug snapshot at $TS ==="
                  ${pkgs.coreutils}/bin/uptime
                  echo "--- /proc/cmdline ---"
                  ${pkgs.coreutils}/bin/cat /proc/cmdline
                  echo "--- /sys/power ---"
                  for f in state mem_sleep disk pm_test image_size resume resume_offset; do
                    if [ -r /sys/power/$f ]; then
                      printf '%s: ' "$f"
                      ${pkgs.coreutils}/bin/cat /sys/power/$f 2>/dev/null || echo "(unreadable)"
                    fi
                  done
                  echo "--- /proc/acpi/wakeup ---"
                  ${pkgs.coreutils}/bin/cat /proc/acpi/wakeup 2>/dev/null || echo "(missing)"
                } > "$DIR/power-state.txt" 2>&1

                ${pkgs.util-linux}/bin/dmesg --ctime --color=never \
                  > "$DIR/dmesg.txt" 2>&1 || true

                ${pkgs.systemd}/bin/journalctl -k -b --no-pager \
                  > "$DIR/journal-kernel.txt" 2>&1 || true

                ${pkgs.systemd}/bin/journalctl -b --no-pager -n 2000 \
                  > "$DIR/journal-tail.txt" 2>&1 || true

                ${pkgs.kmod}/bin/lsmod > "$DIR/lsmod.txt" 2>&1 || true
                ${pkgs.coreutils}/bin/cat /proc/interrupts \
                  > "$DIR/interrupts.txt" 2>&1 || true
                {
                  echo "--- /sys/class/drm ---"
                  for d in /sys/class/drm/card*/device/power; do
                    [ -d "$d" ] || continue
                    echo "## $d"
                    for f in "$d"/runtime_status "$d"/runtime_enabled "$d"/control; do
                      [ -r "$f" ] || continue
                      printf '%s: ' "$f"
                      ${pkgs.coreutils}/bin/cat "$f" 2>/dev/null
                    done
                  done
                } > "$DIR/gpu-power.txt" 2>&1

                {
                  echo "--- /proc/bus/input/devices ---"
                  ${pkgs.coreutils}/bin/cat /proc/bus/input/devices 2>/dev/null
                  echo "--- /sys/class/input ---"
                  ${pkgs.coreutils}/bin/ls -la /sys/class/input/ 2>/dev/null
                } > "$DIR/input.txt" 2>&1

                ${pkgs.coreutils}/bin/ls -1t /var/log/resume-debug/ 2>/dev/null \
                  | ${pkgs.coreutils}/bin/tail -n +31 \
                  | while read old; do
                      ${pkgs.coreutils}/bin/rm -rf "/var/log/resume-debug/$old"
                    done

                exit 0
              '';
            };
          };

          systemd.tmpfiles.rules = [
            "d /var/log/resume-debug 0755 root root - -"
          ];
        };
    };
  };
}
