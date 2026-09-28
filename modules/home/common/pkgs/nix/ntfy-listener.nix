{
  baseUrl ? "http://vps-oracle-0:8111",
  sources ? {
    alerts = "Alerts";
    emre-opencode = "opencode";
    emre-tmux = "tmux";
    emre-laptop = "ntfy";
  },
  soundPath ? null,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  topics = lib.attrNames sources;
  topicStr = lib.concatStringsSep "," topics;
  fullUrl = "${baseUrl}/${topicStr}";
  sourcesFile = pkgs.writeText "ntfy-sources.json" (builtins.toJSON sources);
  resolvedSoundPath =
    if soundPath == null then
      "${config.home.homeDirectory}/.local/share/sounds/effects/nier_enter.mp3"
    else
      soundPath;

  script = pkgs.writeShellApplication {
    name = "ntfy-listener.sh";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.jq
      pkgs.libnotify
      pkgs.ntfy-sh
    ];
    text = builtins.readFile ../bin/ntfy-listener.sh;
  };
in
{
  assertions = [
    {
      assertion =
        topics != [ ]
        && lib.all (topic: builtins.match "[-_A-Za-z0-9]{1,64}" topic != null) topics
        && lib.all (name: name != "") (lib.attrValues sources);
      message = "ntfy-listener: sources must map valid ntfy topic names to non-empty application names.";
    }
  ];

  systemd.user.services.ntfy-listener = {
    Unit = {
      Description = "ntfy subscriber for ${topicStr}";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${script}/bin/ntfy-listener.sh --url ${fullUrl} --sources ${sourcesFile} --sound ${resolvedSoundPath}";
      Restart = "always";
      RestartSec = "10";
      RestartSteps = 5;
      RestartMaxDelaySec = "300";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
