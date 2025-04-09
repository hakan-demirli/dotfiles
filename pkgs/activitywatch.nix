{ pkgs, ... }:
{
  services.activitywatch = {
    enable = false; # use hyprland config
    package = pkgs.aw-server-rust;

    ## Buggy
    # watchers = {
    #   awatcher = {
    #     # requires manually launching awatcher from cli since systemd service fails for some reason
    #     package = pkgs.awatcher;
    #   };

    #   aw-watcher-afk = {
    #     package = pkgs.aw-server-rust;
    #     settings = {
    #       poll_time = 5;
    #       timeout = 180;
    #     };
    #   };

    #   aw-watcher-window = {
    #     package = pkgs.aw-server-rust;
    #     settings = {
    #       exclude_title = false;
    #       poll_time = 1;
    #     };
    #   };
    # };
  };
}
