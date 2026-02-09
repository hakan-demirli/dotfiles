{ pkgs, ... }:

{
  systemd.user.services.ntfy-listener = {
    description = "Ntfy Listener for Laptop Actions";
    after = [ "network-online.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      ExecStart = pkgs.writeShellScript "ntfy-listener" ''
        export PATH=${
          pkgs.lib.makeBinPath [
            pkgs.bash
            pkgs.libnotify
            pkgs.ffmpeg
            pkgs.coreutils
          ]
        }:$PATH

        ${pkgs.ntfy-sh}/bin/ntfy sub -c /dev/null \
          "http://vm-oracle-aarch64:8111/emre-laptop" \
          'bash -c "ffplay -autoexit -nodisp -af volume=2.0 $HOME/.local/share/sounds/effects/nier_enter.mp3 > /dev/null 2>&1 & notify-send \"$t\" \"$m\""'
      '';
      Restart = "always";
      RestartSec = "10";
    };
  };
}
