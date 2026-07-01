{ config, ... }:
{
  systemd.user.services.update-wp = {
    Unit = {
      Description = "Set the daily wallpaper";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.local/bin/update_wp.sh";
    };
  };

  systemd.user.timers.update-wp = {
    Unit = {
      Description = "Update the wallpaper each calendar day";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Timer = {
      OnActiveSec = "5s";
      OnCalendar = "daily";
      AccuracySec = "1s";
      Persistent = true;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
