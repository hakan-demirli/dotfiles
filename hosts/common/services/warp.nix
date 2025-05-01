{
  pkgs,
  ...
}:
{
  services.cloudflare-warp = {
    enable = true;
    package = pkgs.cloudflare-warp;
  };
  environment.persistence."/persist/system" = {
    directories = [
      "/var/lib/cloudflare-warp"
    ];
  };
  # https://github.com/NixOS/nixpkgs/issues/336280#issuecomment-2303888524
  systemd.user.services.warp-taskbar.wantedBy = [ "graphical.target" ];
}
