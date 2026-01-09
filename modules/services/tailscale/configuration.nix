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

        # Make tailscaled-autoconnect non-blocking so nixos-rebuild switch doesn't hang when offline
        systemd.services.tailscaled-autoconnect = {
          # Keep it in wantedBy so it starts automatically (don't use mkForce to disable)
          # But make it non-blocking if it fails
          unitConfig = {
            # Don't block other services if this fails to start
            DefaultDependencies = false;
          };
          serviceConfig = {
            # Timeout quickly if network is unavailable
            TimeoutStartSec = "5s";
            # Don't restart on failure (will be retried on next boot/network change)
            Restart = "no";
          };
        };
      };
    };
}
