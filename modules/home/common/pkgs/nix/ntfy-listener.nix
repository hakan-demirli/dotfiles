{
  baseUrl ? "http://vps-oracle-0:8111",
  topics ? [
    "emre-laptop"
    "alerts"
  ],
  soundPath ? null,
}:
{ config, pkgs, ... }:
let
  topicStr = builtins.concatStringsSep "," topics;
  fullUrl = "${baseUrl}/${topicStr}";
  resolvedSoundPath =
    if soundPath == null then
      "${config.home.homeDirectory}/.local/share/sounds/effects/nier_enter.mp3"
    else
      soundPath;

  script = pkgs.writeShellApplication {
    name = "ntfy-listener.sh";
    runtimeInputs = [
      pkgs.bash
      pkgs.libnotify
      pkgs.ffmpeg
      pkgs.coreutils
      pkgs.ntfy-sh
    ];
    text = builtins.readFile ../bin/ntfy-listener.sh;
  };
in
{
  systemd.user.services.ntfy-listener = {
    Unit = {
      Description = "ntfy subscriber for ${topicStr}";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${script}/bin/ntfy-listener.sh --url ${fullUrl} --sound ${resolvedSoundPath}";
      Restart = "always";
      RestartSec = "10";
      RestartSteps = 5;
      RestartMaxDelaySec = "300";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
