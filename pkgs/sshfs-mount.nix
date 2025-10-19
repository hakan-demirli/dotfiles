{ pkgs, ... }:

let
  username = "emre";
  userHome = "/home/${username}";
  mountPoint = "${userHome}/.local/share/repx-store";
  remoteHost = "tailscale-s01";
  remotePath = "/home/emre/.local/share/repx-store";

  binPath = pkgs.lib.makeBinPath [
    pkgs.sshfs-fuse
    pkgs.fuse
    pkgs.bash
    pkgs.coreutils
  ];

in
{
  systemd.services.sshfs-repx-store = {
    description = "Mount remote repx-store via sshfs with auto-reconnect";

    after = [
      "network-online.target"
      "tailscale-up.service"
    ];
    wants = [
      "network-online.target"
      "tailscale-up.service"
    ];

    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";

      User = username;
      Group = "users";

      Environment = [
        "PATH=${binPath}"
        "HOME=${userHome}"
        "USER=${username}"
      ];

      ExecStartPre = ''
        ${pkgs.bash}/bin/bash -c "${pkgs.coreutils}/bin/mkdir -p ${mountPoint} && ${pkgs.fuse}/bin/fusermount -u ${mountPoint} || true"
      '';

      ExecStart = ''
        ${pkgs.sshfs-fuse}/bin/sshfs \
          -f \
          -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,allow_other \
          -o IdentityFile=${userHome}/.ssh/id_ed25519 \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          ${remoteHost}:${remotePath} \
          ${mountPoint}
      '';

      ExecStop = "${pkgs.fuse}/bin/fusermount -u ${mountPoint}";

      StandardOutput = "journal";
      StandardError = "journal";

      Restart = "always";
      RestartSec = "15s";
    };
  };
}
