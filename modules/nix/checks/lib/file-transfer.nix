{
  pkgs,
  self,
  lib,
}:
let
  laptop = self.nixosConfigurations.laptop-1.config;
  inbox = laptop.services.rsyncd.settings.sections.inbox;
  homeSendPackage = lib.findFirst (
    package: lib.getName package == "send-to-laptop"
  ) null self.homeConfigurations."user-0@headless".config.home.packages;
  sendPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.send-to-laptop;
  gtransfer = self + /modules/home/common/pkgs/bin/gtransfer.sh;
  mockFzf = pkgs.writeShellScriptBin "fzf" ''
    menu=$(cat)
    grep -qx laptop-1-inbox <<< "$menu"
    printf '%s\n' laptop-1-inbox
  '';
  mockSend = pkgs.writeShellScriptBin "send-to-laptop" ''
    printf '%s\0' "$@" > "$MOCK_ARGS"
  '';

  checks = {
    ssh-disabled =
      !laptop.services.openssh.enable
      && !(laptop.systemd.services ? sshd)
      && !(lib.elem 22 laptop.networking.firewall.allowedTCPPorts);
    rsync-write-only =
      laptop.services.rsyncd.enable
      && laptop.services.rsyncd.socketActivated
      && inbox."read only" == false
      && inbox."write only" == true
      && inbox.list == false;
    rsync-tailnet-only =
      laptop.systemd.sockets.rsync.socketConfig.BindToDevice == "tailscale0"
      && !(lib.elem laptop.services.rsyncd.port laptop.networking.firewall.allowedTCPPorts);
    rsync-acyclic-ordering =
      laptop.systemd.sockets.rsync.unitConfig.DefaultDependencies == false
      && lib.elem "tailscaled.service" laptop.systemd.sockets.rsync.after
      && lib.elem "tailscaled.service" laptop.systemd.sockets.rsync.requires
      && lib.elem "shutdown.target" laptop.systemd.sockets.rsync.before
      && lib.elem "shutdown.target" laptop.systemd.sockets.rsync.conflicts;
    sender-installed = homeSendPackage != null;
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
pkgs.runCommand "file-transfer-policy"
  {
    failureCount = toString (lib.length failures);
    failureNames = lib.concatStringsSep "," failures;
    inherit sendPackage;
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.rsync
      mockFzf
      mockSend
    ];
  }
  ''
    if [[ "$failureCount" != 0 ]]; then
      echo "failed file transfer checks: $failureNames" >&2
      exit 1
    fi

    test -x "$sendPackage/bin/send-to-laptop"
    set +e
    "$sendPackage/bin/send-to-laptop" >/dev/null 2>&1
    status=$?
    set -e
    test "$status" -eq 2

    mkdir -p "$TMPDIR/home" "$TMPDIR/files"
    touch "$TMPDIR/files/first file" "$TMPDIR/files/second"
    export HOME="$TMPDIR/home"
    export MOCK_ARGS="$TMPDIR/args"
    bash ${gtransfer} "$TMPDIR/files/first file" "$TMPDIR/files/second"

    mapfile -d "" -t args < "$MOCK_ARGS"
    test "''${#args[@]}" -eq 2
    test "''${args[0]}" = "$TMPDIR/files/first file"
    test "''${args[1]}" = "$TMPDIR/files/second"

    mkdir -p "$TMPDIR/inbox" "$TMPDIR/empty"
    cat > "$TMPDIR/rsyncd.conf" <<EOF
    address=127.0.0.1
    port=18730
    use chroot=false

    [inbox]
    path=$TMPDIR/inbox
    read only=false
    write only=true
    list=false
    incoming chmod=Du=rwx,Dgo=,Fu=rw,Fgo=
    refuse options=delete delete-before delete-during delete-delay delete-after delete-excluded
    EOF

    rsync --daemon --no-detach --config="$TMPDIR/rsyncd.conf" &
    daemon=$!
    trap 'kill "$daemon" 2>/dev/null || true' EXIT

    printf '%s\n' original > "$TMPDIR/payload"
    sent=false
    for _ in $(seq 1 50); do
      if rsync --ignore-existing "$TMPDIR/payload" rsync://127.0.0.1:18730/inbox/; then
        sent=true
        break
      fi
      sleep 0.1
    done
    "$sent"
    test "$(cat "$TMPDIR/inbox/payload")" = original
    test "$(stat -c %a "$TMPDIR/inbox/payload")" = 600

    printf '%s\n' replacement > "$TMPDIR/payload"
    rsync --ignore-existing "$TMPDIR/payload" rsync://127.0.0.1:18730/inbox/
    test "$(cat "$TMPDIR/inbox/payload")" = original

    if rsync rsync://127.0.0.1:18730/inbox/payload "$TMPDIR/download"; then
      echo "write-only inbox allowed a download" >&2
      exit 1
    fi
    if rsync --recursive --delete "$TMPDIR/empty/" rsync://127.0.0.1:18730/inbox/; then
      echo "write-only inbox accepted a remote delete" >&2
      exit 1
    fi
    test -f "$TMPDIR/inbox/payload"

    kill "$daemon"
    wait "$daemon" || true
    trap - EXIT
    touch "$out"
  ''
