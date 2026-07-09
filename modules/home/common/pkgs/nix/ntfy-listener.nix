{
  baseUrl ? "http://vm-oracle-aarch64:8111",
  topics ? [ "emre-laptop" ],
  soundPath ? "$HOME/.local/share/sounds/effects/nier_enter.mp3",
}:
{ pkgs, ... }:
let
  topicStr = builtins.concatStringsSep "," topics;
  fullUrl = "${baseUrl}/${topicStr}";
in
{
  systemd.user.services.ntfy-listener = {
    Unit = {
      Description = "ntfy subscriber for ${topicStr}";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
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
          "${fullUrl}" \
          'bash -c "ffplay -autoexit -nodisp -af volume=2.0 ${soundPath} > /dev/null 2>&1 & notify-send \"$t\" \"$m\""'
      '';
      Restart = "always";
      RestartSec = "10";
      RestartSteps = 5;
      RestartMaxDelaySec = "300";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
