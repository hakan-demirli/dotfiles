{ pkgs, ... }:
{
  services.activitywatch = {
    enable = false;
    package = pkgs.aw-server-rust;
  };
}
