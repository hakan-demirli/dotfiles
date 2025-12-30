{
  inputs,
  ...
}:
{
  # Reverse SSH tunnel server (gateway ports)
  flake.modules.nixos.services-reverse-ssh-server = { config, lib, ... }:
  let
    cfg = config.services.reverse-ssh-server;
  in
  {
    options.services.reverse-ssh-server = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable reverse SSH tunnel server (gateway ports)";
      };
      allowedTCPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
        description = "TCP ports to allow in firewall";
      };
    };

    config = lib.mkIf cfg.enable {
      services.openssh.settings = {
        GatewayPorts = "clientspecified";
        AllowTcpForwarding = true;
      };

      networking.firewall = {
        enable = true;
        allowedTCPPorts = cfg.allowedTCPPorts;
      };
    };
  };
}
