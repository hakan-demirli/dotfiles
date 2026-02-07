{ pkgs, ... }:

{
  systemd.user.services.ntfy-listener = {
    Unit = {
      Description = "Ntfy Listener for Laptop Actions";
      After = [ "network-online.target" ];
    };

    Service = {
      ExecStart = pkgs.writeShellScript "ntfy-listener" ''
        export PATH=${
          pkgs.lib.makeBinPath [
            pkgs.libnotify
            pkgs.ffmpeg
            pkgs.coreutils
          ]
        }:$PATH

        ${pkgs.ntfy-sh}/bin/ntfy sub -c /dev/null \
          "http://vm-oracle-aarch64:8111/emre/laptop" \
          'bash -c "ffplay -autoexit -nodisp -af volume=2.0 $HOME/.local/share/sounds/effects/nier_enter.mp3 > /dev/null 2>&1 & notify-send \"$t\" \"$m\""'
      '';
      Restart = "always";
      RestartSec = "10";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
