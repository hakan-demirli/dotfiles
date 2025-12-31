{
  flake.modules.nixos.services-tailscale =
    { config, lib, ... }:
    let
      cfg = config.services.tailscale;
    in
    {
      options.services.tailscale.reverseSshRemoteHost = lib.mkOption {
        type = lib.types.str;
        description = "Reverse SSH Remote Host for Tailscale login server";
      };

      config = {
        # you must disconnect warp
        # warp-cli disconnect
        sops.secrets.tailscale-key = { };

        services.tailscale = {
          enable = true;
          authKeyFile = config.sops.secrets.tailscale-key.path;
          useRoutingFeatures = "client";
          extraUpFlags = [
            "--login-server=https://${cfg.reverseSshRemoteHost}"
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

        # Dont block switch if network is down
        systemd.services.tailscaled-autoconnect = {
          # Don't block nixos-rebuild switch if this fails
          wantedBy = lib.mkForce [ ];
          serviceConfig = {
            TimeoutStartSec = "5s";
            Restart = "no";
          };
        };
      };
    };
}
