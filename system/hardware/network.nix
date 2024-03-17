{
  pkgs,
  userSettings,
  systemSettings,
  ...
}: {
  # Enable networking
  networking.networkmanager.enable = true;
  networking.hostName = systemSettings.hostname; # Define your hostname.
  networking.extraHosts = ''
    0.0.0.0  9gag.com
    0.0.0.0  www.9gag.com
    0.0.0.0  reddit.com
    0.0.0.0  www.reddit.com
  '';

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1; # required to share your internet
    # "net.ipv6.conf.all.forwarding" = 1;
  };
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
}
