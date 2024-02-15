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

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
