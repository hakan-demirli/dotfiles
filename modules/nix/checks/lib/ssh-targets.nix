{
  pkgs,
  self,
}:
let
  sshTargets = self + /modules/home/common/pkgs/bin/ssh-targets.sh;
  tailscaleStatus = pkgs.writeText "tailscale-status.json" (
    builtins.toJSON {
      Peer = {
        peer-a = {
          DNSName = "vps-oracle-0.ts.example.test.";
          Online = true;
        };
        peer-b = {
          DNSName = "server-dev-1.ts.example.test.";
          Online = false;
        };
        peer-c = {
          DNSName = "";
          Online = true;
        };
      };
    }
  );
  mockTailscale = pkgs.writeShellScriptBin "tailscale" ''
    cat ${tailscaleStatus}
  '';
in
pkgs.runCommand "ssh-targets"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gawk
      pkgs.jq
      mockTailscale
    ];
  }
  ''
    mkdir -p "$TMPDIR/home/.ssh"
    cat > "$TMPDIR/home/.ssh/config" <<'EOF'
    Host alpha beta
    Host *.example.test !blocked.example.test
    Host alpha gamma # trailing comment
    EOF

    HOME="$TMPDIR/home" bash ${sshTargets} > "$TMPDIR/actual"
    cat > "$TMPDIR/expected" <<'EOF'
    alpha
    beta
    gamma
    vps-oracle-0.ts.example.test
    server-dev-1.ts.example.test
    EOF
    diff -u "$TMPDIR/expected" "$TMPDIR/actual"
    touch "$out"
  ''
