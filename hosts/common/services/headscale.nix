{
  reverseSshRemoteHost ? throw "You must specify a reverseSshRemoteHost",
  allowedUDPPorts ? [ ],
  ...
}:
{
  services = {
    headscale = {
      enable = true;
      settings = {
        server_url = "https://${reverseSshRemoteHost}";
        listen_addr = "0.0.0.0:8080";
        ip_prefixes = [
          "100.64.0.0/10"
        ];

        policy.path = ./headscale-acl.hujson;

        dns = {
          magic_dns = true;
          base_domain = "ts.${reverseSshRemoteHost}";
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

          paths = [ ./derp.yaml ];

          auto_update_enabled = true;
          update_frequency = "24h";
        };
      };
    };

    caddy = {
      enable = true;
      virtualHosts."${reverseSshRemoteHost}" = {
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
      authKeyFile = "/persist/home/emre/Desktop/dotfiles/secrets/tailscale-key";
      extraUpFlags = [
        "--login-server=https://${reverseSshRemoteHost}"
        "--advertise-exit-node"
      ];
    };
  };

  environment.persistence."/persist/system".directories = [
    "/var/lib/headscale"
    "/var/lib/tailscale"
    "/var/lib/caddy"
  ];
  networking.firewall = {
    enable = true;
    inherit allowedUDPPorts;
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}
