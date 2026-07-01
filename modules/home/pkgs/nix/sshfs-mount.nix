{
  name ? "repx-store",
  remoteHost ? "tailscale-s01",
  remotePath ? "/home/emre/.local/share/repx-store",
  mountPoint ? "$HOME/.local/share/repx-store",
  identityFile ? null,
}:
{ pkgs, ... }:
let
  identityOpt = if identityFile == null then "" else "-o IdentityFile=${identityFile}";
in
{
  systemd.user.services."sshfs-${name}" = {
    Unit = {
      Description = "sshfs mount of ${remoteHost}:${remotePath} -> ${mountPoint}";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.sshfs-fuse
            pkgs.fuse
            pkgs.bash
            pkgs.coreutils
          ]
        }"
      ];
      ExecStartPre = "${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/mkdir -p ${mountPoint} && ${pkgs.fuse}/bin/fusermount -u ${mountPoint} || true'";
      ExecStart = ''
        ${pkgs.sshfs-fuse}/bin/sshfs \
          -f \
          -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3 \
          ${identityOpt} \
          ${remoteHost}:${remotePath} \
          ${mountPoint}
      '';
      ExecStop = "${pkgs.fuse}/bin/fusermount -u ${mountPoint}";
      Restart = "always";
      RestartSec = "15s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
