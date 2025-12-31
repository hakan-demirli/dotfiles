{
  inputs,
  ...
}:
{
  flake.modules.nixos.services-headscale =
    { config, lib, ... }:
    let
      cfg = config.services.headscale-server;
    in
    {
      options.services.headscale-server = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Headscale control server with Caddy";
        };
        serverUrl = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Public URL for Headscale (e.g., sshr.example.com)";
        };
        allowedUDPPorts = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [
            3478
            41641
          ];
          description = "UDP ports to allow for STUN/Tailscale discovery";
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets.tailscale-key = { };

        services = {
          headscale = {
            enable = true;
            settings = {
              server_url = "https://${cfg.serverUrl}";
              listen_addr = "0.0.0.0:8080";
              ip_prefixes = [ "100.64.0.0/10" ];

              policy.path = inputs.self + /modules/services/headscale/headscale-acl.hujson;

              dns = {
                magic_dns = true;
                base_domain = "ts.${cfg.serverUrl}";
                nameservers = {
                  global = [
                    "1.1.1.1"
                    "8.8.8.8"
                  ];
                };
              };

              derp = {
                server = {
                  enable = true;
                  region_id = 999;
                  region_code = "oracle-vps";
                  region_name = "Oracle Cloud VPS";
                  private_key_path = "/var/lib/headscale/derp_server.key";
                };
                stun.listen_addr = "0.0.0.0:3478";
                paths = [ (inputs.self + /modules/services/headscale/derp.yaml) ];
                auto_update_enabled = true;
                update_frequency = "24h";
              };
            };
          };

          caddy = {
            enable = true;
            virtualHosts."${cfg.serverUrl}" = {
              extraConfig = ''
                # Headscale traffic
                reverse_proxy http://127.0.0.1:8080

                # DERP traffic (upgrades to a TCP tunnel)
                @derp {
                    path /derp/*
                    header Connection Upgrade
                    header Upgrade websocket
                }
                reverse_proxy @derp http://127.0.0.1:8080
              '';
            };
          };

          tailscale = {
            enable = true;
            authKeyFile = config.sops.secrets.tailscale-key.path;
            extraUpFlags = [
              "--login-server=https://${cfg.serverUrl}"
              "--advertise-exit-node"
            ];
          };
        };

        environment.persistence."/persist".directories = [
          "/var/lib/headscale"
          "/var/lib/tailscale"
          "/var/lib/caddy"
        ];

        networking.firewall = {
          enable = true;
          inherit (cfg) allowedUDPPorts;
        };

        boot.kernel.sysctl = {
          "net.ipv4.ip_forward" = 1;
          "net.ipv6.conf.all.forwarding" = 1;
        };
      };
    };
}
