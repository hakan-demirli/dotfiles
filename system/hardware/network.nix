{
  pkgs,
  userSettings,
  systemSettings,
  ...
}: {
  # Enable networking
  networking.networkmanager.enable = true;
  networking.hostName = systemSettings.hostname; # Define your hostname.

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
