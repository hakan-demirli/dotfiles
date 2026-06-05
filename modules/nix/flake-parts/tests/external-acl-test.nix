_: {
  perSystem =
    { config, pkgs, ... }:
    {
      apps.test-external-acl = {
        type = "app";
        program = "${config.packages.external-acl-test.driver}/bin/nixos-test-driver";
        meta.description = "Run the tag:external ACL integration test";
      };

      packages.external-acl-test =
        let
          aclFile = ../../../services/headscale/headscale-acl.hujson;

          tls-cert = pkgs.runCommand "selfSignedCerts" { buildInputs = [ pkgs.openssl ]; } ''
            openssl req \
              -x509 -newkey rsa:4096 -sha256 -days 365 \
              -nodes -out cert.pem -keyout key.pem \
              -subj '/CN=headscale' -addext "subjectAltName=DNS:headscale"

            mkdir -p $out
            cp key.pem cert.pem $out
          '';

          derpMap = pkgs.writeText "derp.yaml" ''
            regions:
              900:
                regionid: 900
                regioncode: "test"
                regionname: "Test Region"
                nodes:
                  - name: "900a"
                    regionid: 900
                    hostname: "headscale"
                    ipv4: "192.168.1.1"
                    stunport: 3478
                    derpport: 443
          '';

          mkTailscaleClient = _: {
            services.tailscale = {
              enable = true;
              port = 41641;
              extraUpFlags = [ "--login-server=https://headscale" ];
            };

            systemd.services.tailscaled.environment = {
              TS_NO_UDP_GROT = "1";
              TS_DEBUG_NETCHECK = "0";
            };
            systemd.services.tailscaled.serviceConfig.LogLevelMax = "notice";

            security.pki.certificateFiles = [ "${tls-cert}/cert.pem" ];

            networking.firewall = {
              enable = true;
              allowedUDPPorts = [ 41641 ];
              checkReversePath = "loose";
              trustedInterfaces = [ "tailscale0" ];
            };
            networking.extraHosts = "192.168.1.1 headscale";
          };
        in
        pkgs.testers.runNixOSTest {
          name = "external-acl-test";

          nodes = {
            a00_headscale =
              { pkgs, ... }:
              {
                services = {
                  headscale = {
                    enable = true;
                    settings = {
                      server_url = "https://headscale";
                      listen_addr = "127.0.0.1:8080";
                      ip_prefixes = [ "100.64.0.0/10" ];
                      policy.path = aclFile;
                      dns = {
                        magic_dns = true;
                        base_domain = "ts.sshr.polarbearvuzi.com";
                        nameservers.global = [ "1.1.1.1" ];
                      };

                      derp = {
                        server = {
                          enable = true;
                          region_code = "test";
                          region_id = 900;
                          private_key_path = "/var/lib/headscale/derp.key";
                          stun_listen_addr = "0.0.0.0:3478";
                        };
                        urls = [ ];
                        paths = [ derpMap ];
                      };
                    };
                  };

                  nginx = {
                    enable = true;
                    virtualHosts.headscale = {
                      addSSL = true;
                      sslCertificate = "${tls-cert}/cert.pem";
                      sslCertificateKey = "${tls-cert}/key.pem";
                      locations."/" = {
                        proxyPass = "http://127.0.0.1:8080";
                        proxyWebsockets = true;
                        extraConfig = ''
                          proxy_read_timeout 600s;
                          proxy_set_header Upgrade $http_upgrade;
                          proxy_set_header Connection "upgrade";
                          proxy_set_header Host $host;
                          proxy_set_header X-Real-IP $remote_addr;
                          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          proxy_set_header X-Forwarded-Proto $scheme;
                        '';
                      };
                    };
                  };
                };

                networking.firewall = {
                  enable = true;
                  allowedTCPPorts = [
                    80
                    443
                  ];
                  allowedUDPPorts = [ 3478 ];
                };
                environment.systemPackages = [ pkgs.headscale ];
              };

            ss0 = mkTailscaleClient;

            emre_laptop = mkTailscaleClient;
            emre_phone = mkTailscaleClient;

            external_machine = mkTailscaleClient;
          };

          testScript = ''
            start_all()

            a00_headscale.wait_for_unit("headscale.service")
            a00_headscale.wait_for_open_port(8080)
            a00_headscale.wait_for_open_port(443)

            a00_headscale.succeed("headscale users create emre")

            server_key   = a00_headscale.succeed("headscale preauthkeys create --reusable --expiration 24h --tags tag:shared-server").strip()
            laptop_key   = a00_headscale.succeed("headscale preauthkeys create --reusable --expiration 24h --tags tag:laptop").strip()
            phone_key    = a00_headscale.succeed("headscale preauthkeys create --reusable --expiration 24h --tags tag:phone").strip()
            external_key = a00_headscale.succeed("headscale preauthkeys create --reusable --expiration 24h --tags tag:external").strip()

            ss0.wait_for_unit("tailscaled.service")
            ss0.succeed(f"tailscale up --authkey={server_key} --hostname=ss0 --login-server=https://headscale")

            emre_laptop.wait_for_unit("tailscaled.service")
            emre_laptop.succeed(f"tailscale up --authkey={laptop_key} --hostname=emre-l01 --login-server=https://headscale")

            emre_phone.wait_for_unit("tailscaled.service")
            emre_phone.succeed(f"tailscale up --authkey={phone_key} --hostname=emre-phone --login-server=https://headscale")

            external_machine.wait_for_unit("tailscaled.service")
            external_machine.succeed(f"tailscale up --authkey={external_key} --hostname=external-guest --login-server=https://headscale")

            a00_headscale.wait_until_succeeds("headscale nodes list | grep ss0")
            a00_headscale.wait_until_succeeds("headscale nodes list | grep emre-l01")
            a00_headscale.wait_until_succeeds("headscale nodes list | grep emre-phone")
            a00_headscale.wait_until_succeeds("headscale nodes list | grep external-guest")

            def get_ts_ip(node):
                return node.succeed("tailscale ip -4").strip()

            ss0_ip          = get_ts_ip(ss0)
            laptop_ip       = get_ts_ip(emre_laptop)
            phone_ip        = get_ts_ip(emre_phone)
            external_ip     = get_ts_ip(external_machine)

            print(f"ss0 IP:        {ss0_ip}")
            print(f"laptop IP:     {laptop_ip}")
            print(f"phone IP:      {phone_ip}")
            print(f"external IP:   {external_ip}")

            emre_laptop.wait_until_succeeds(f"ping -c 2 {ss0_ip}")

            external_machine.wait_until_succeeds(f"ping -c 2 {ss0_ip}")

            external_machine.fail(f"ping -c 2 -W 1 {laptop_ip}")
            external_machine.fail(f"ping -c 2 -W 1 {phone_ip}")

            emre_laptop.fail(f"ping -c 2 -W 1 {external_ip}")
            emre_phone.fail(f"ping -c 2 -W 1 {external_ip}")
            ss0.fail(f"ping -c 2 -W 1 {external_ip}")

            print("ALL VERIFICATIONS PASSED")
          '';
        };
    };
}
