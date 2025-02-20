{ pkgs }:
{
  services = {
    xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];
    };
  };
}
