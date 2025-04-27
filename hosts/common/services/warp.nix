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
}
