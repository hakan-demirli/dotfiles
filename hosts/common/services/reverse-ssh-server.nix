{
  allowedTCPPorts ? [ ],
  ...
}:
{
  services.openssh.settings = {
    GatewayPorts = "clientspecified";
    AllowTcpForwarding = true;
  };

  networking.firewall = {
    enable = true;
    inherit allowedTCPPorts;
  };
}
