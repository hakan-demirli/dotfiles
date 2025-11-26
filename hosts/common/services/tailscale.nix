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

  networking = {
    firewall = {
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
      allowedUDPPorts = [ config.services.tailscale.port ];
    };

    networkmanager.unmanaged = [ "tailscale0" ];
    networkmanager.dns = "systemd-resolved";
  };

  services.resolved.enable = true;
  environment.persistence."/persist/system".directories = [
    "/var/lib/tailscale"
  ];
}
