{
  config,
  reverseSshRemoteHost ? throw "You must specify a reverseSshRemoteHost",
  ...
}:
{
  # you must disconnect warp
  # warp-cli disconnect
  services.tailscale = {
    enable = true;
    authKeyFile = "/persist/home/emre/Desktop/dotfiles/secrets/tailscale-key";
    useRoutingFeatures = "client";
    extraUpFlags = [
      "--login-server=https://${reverseSshRemoteHost}"
    ];
  };

  networking.firewall = {
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  networking.networkmanager.unmanaged = [ "tailscale0" ];

  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  environment.persistence."/persist/system".directories = [
    "/var/lib/tailscale"
  ];
}
