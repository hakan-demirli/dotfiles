{
  flake.modules.nixos.services-tailscale =
    { config, lib, ... }:
    let
      cfg = config.services.tailscale;
    in
    {
      options.services.tailscale = {
        loginServerHost = lib.mkOption {
          type = lib.types.str;
          description = "Headscale login server hostname";
        };
        useAuthKey = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to use a sops-managed auth key for automatic registration. When false, register manually via `sudo tailscale up`.";
        };
      };

      config = {
        # you must disconnect warp
        # warp-cli disconnect
        sops.secrets.tailscale-key = lib.mkIf cfg.useAuthKey { };

        services.tailscale = {
          enable = true;
          authKeyFile = lib.mkIf cfg.useAuthKey config.sops.secrets.tailscale-key.path;
          useRoutingFeatures = "client";
          extraUpFlags = [
            "--login-server=https://${cfg.loginServerHost}"
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
