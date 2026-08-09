{ pkgs, ... }:
let
  screenRecord = pkgs.writeShellApplication {
    name = "screen-record";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      libnotify
      procps
      pulseaudio
      slurp
      systemd
      util-linux
      wl-clipboard
      wl-screenrec
    ];
    text = builtins.readFile ../bin/screen-record.sh;
  };
in
{
  home.packages = [
    screenRecord
    pkgs.wl-screenrec
  ];

  systemd.user.services.screen-record = {
    Unit.Description = "Wayland screen recording";
    Service = {
      Type = "exec";
      ExecStart = "${screenRecord}/bin/screen-record run";
      ExecStopPost = "${screenRecord}/bin/screen-record finish";
      KillSignal = "SIGINT";
      TimeoutStopSec = "30s";
    };
  };
}
