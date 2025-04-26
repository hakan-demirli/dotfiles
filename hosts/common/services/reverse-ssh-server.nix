{
  allowedPorts ? [ ],
  ...
}:
{
  services.openssh.settings = {
    GatewayPorts = "clientspecified";
    AllowTcpForwarding = true;
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = allowedPorts;
  };
}
