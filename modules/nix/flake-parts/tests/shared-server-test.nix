_: {
  perSystem =
    { config, pkgs, ... }:
    {
      apps.test = {
        type = "app";
        program = "${config.legacyPackages.integrationChecks.shared-server-test.driver}/bin/nixos-test-driver";
        meta.description = "Run the shared server ACL integration test";
      };

      legacyPackages.integrationChecks.shared-server-test =
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
        in
        pkgs.testers.runNixOSTest {
          name = "shared-server-acl-test";

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

            shared_server =
              { config, pkgs, ... }:
              {
                virtualisation.containers.enable = true;

                services.tailscale = {
                  enable = true;
                  port = 41641;
                  extraUpFlags = [
                    "--advertise-tags=tag:shared-server"
                    "--login-server=https://headscale"
                  ];
                };

                systemd.services.tailscaled.environment = {
                  TS_NO_UDP_GROT = "1";
                  TS_DEBUG_NETCHECK = "0";
                };
                systemd.services.tailscaled.serviceConfig.LogLevelMax = "notice";

                security.pki.certificateFiles = [ "${tls-cert}/cert.pem" ];

                users.users = {
                  emre = {
                    isNormalUser = true;
                    uid = 1000;
                    extraGroups = [ "wheel" ];
                  };
                  um = {
                    isNormalUser = true;
                    uid = 1001;
                    extraGroups = [ "wheel" ];
                  };
                };

                networking = {
                  nat = {
                    enable = true;
                    internalInterfaces = [ "ve-+" ];
                    externalInterface = "eth1";
                  };
                  extraHosts = "192.168.1.1 headscale";
                  firewall.checkReversePath = "loose";
                };
                environment.systemPackages = [ pkgs.netcat ];

                containers = {
                  alice = {
                    autoStart = true;
                    privateNetwork = true;
                    hostAddress = "192.168.100.10";
                    localAddress = "192.168.100.11";
                    forwardPorts = [
                      {
                        protocol = "tcp";
                        hostPort = 2201;
                        containerPort = 22;
                      }
                    ];
                    config = _: {
                      networking.firewall.allowedTCPPorts = [ 22 ];
                      system.stateVersion = "25.05";
                      users.users.alice = {
                        isNormalUser = true;
                        extraGroups = [ "wheel" ];
                      };
                    };
                  };

                  bob = {
                    autoStart = true;
                    privateNetwork = true;
                    hostAddress = "192.168.101.10";
                    localAddress = "192.168.101.11";
                    forwardPorts = [
                      {
                        protocol = "tcp";
                        hostPort = 2202;
                        containerPort = 22;
                      }
                    ];
                    config = _: {
                      networking.firewall.allowedTCPPorts = [ 22 ];
                      system.stateVersion = "25.05";
                      users.users.bob = {
                        isNormalUser = true;
                        extraGroups = [ "wheel" ];
                      };
                    };
                  };
                };
                networking.firewall = {
                  enable = true;
                  allowedUDPPorts = [ config.services.tailscale.port ];
                  trustedInterfaces = [ "tailscale0" ];
                };
              };

            emre_machine =
              { config, ... }:
              {
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

                users.users.emre = {
                  isNormalUser = true;
                  uid = 1000;
                };
                networking.firewall = {
                  enable = true;
                  allowedUDPPorts = [ config.services.tailscale.port ];
                  checkReversePath = "loose";
                  trustedInterfaces = [ "tailscale0" ];
                };
                networking.extraHosts = "192.168.1.1 headscale";
              };

            um_machine =
              { config, ... }:
              {
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

                users.users.um = {
                  isNormalUser = true;
                  uid = 1001;
                };
                networking.firewall = {
                  enable = true;
                  allowedUDPPorts = [ config.services.tailscale.port ];
                  checkReversePath = "loose";
                  trustedInterfaces = [ "tailscale0" ];
                };
                networking.extraHosts = "192.168.1.1 headscale";
              };

            ssh_target =
              { config, ... }:
              {
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
                  allowedUDPPorts = [ config.services.tailscale.port ];
                  checkReversePath = "loose";
                  trustedInterfaces = [ "tailscale0" ];
                };
                networking.extraHosts = "192.168.1.1 headscale";
              };
          };

          testScript = ''
            start_all()

            a00_headscale.wait_for_unit("headscale.service")
            a00_headscale.wait_for_open_port(8080)
            a00_headscale.wait_for_open_port(443)

            a00_headscale.succeed("headscale users create emre")
            a00_headscale.succeed("headscale users create um")

            def get_user_id(username):
                import json
                output = a00_headscale.succeed("headscale users list --output json")
                users = json.loads(output)
                for user in users:
                    if user.get("name") == username:
                        return user["id"]
                raise Exception(f"User {username} not found in output: {output}")

            emre_id = get_user_id("emre")
            um_id = get_user_id("um")

            emre_key = a00_headscale.succeed(f"headscale preauthkeys create --user {emre_id} --reusable --expiration 24h").strip()
            um_key = a00_headscale.succeed(f"headscale preauthkeys create --user {um_id} --reusable --expiration 24h").strip()

            server_key = a00_headscale.succeed(f"headscale preauthkeys create --user {emre_id} --reusable --expiration 24h --tags tag:shared-server").strip()
            laptop_key = a00_headscale.succeed(f"headscale preauthkeys create --user {emre_id} --reusable --expiration 24h --tags tag:laptop").strip()
            ssh_key = a00_headscale.succeed(f"headscale preauthkeys create --user {emre_id} --reusable --expiration 24h --tags tag:sshable").strip()

            shared_server.wait_for_unit("tailscaled.service")
            shared_server.succeed(f"tailscale up --authkey={server_key} --hostname=shared-server --advertise-tags=tag:shared-server --login-server=https://headscale --ssh")

            ssh_target.wait_for_unit("tailscaled.service")
            ssh_target.succeed(f"tailscale up --authkey={ssh_key} --hostname=ssh-target --advertise-tags=tag:sshable --ssh --login-server=https://headscale")

            emre_machine.wait_for_unit("tailscaled.service")

            emre_machine.succeed("ping -c 1 192.168.1.1 >&2")

            emre_machine.succeed(f"tailscale up --authkey={laptop_key} --hostname=emre-laptop --advertise-tags=tag:laptop --login-server=https://headscale")

            um_machine.wait_for_unit("tailscaled.service")
            um_machine.succeed(f"tailscale up --authkey={um_key} --hostname=um-laptop --login-server=https://headscale")

            a00_headscale.wait_until_succeeds("headscale nodes list | grep shared-server")
            a00_headscale.wait_until_succeeds("headscale nodes list | grep ssh-target")
            a00_headscale.wait_until_succeeds("headscale nodes list | grep emre-laptop")
            a00_headscale.wait_until_succeeds("headscale nodes list | grep um-laptop")

            def get_ts_ip(node):
                return node.succeed("tailscale ip -4").strip()

            server_ip = get_ts_ip(shared_server)
            ssh_target_ip = get_ts_ip(ssh_target)
            emre_ip = get_ts_ip(emre_machine)
            um_ip = get_ts_ip(um_machine)

            print(f"Server IP: {server_ip}")
            print(f"Emre IP: {emre_ip}")
            print(f"Um IP: {um_ip}")
            print(f"SSH Target IP: {ssh_target_ip}")



            # Test connectivity - both groups can reach shared server
            emre_machine.wait_until_succeeds(f"ping -c 2 {server_ip}")
            um_machine.wait_until_succeeds(f"ping -c 2 {server_ip}")

            # Test ACL isolation - groups CANNOT ping each other
            um_machine.fail(f"ping -c 2 -W 1 {emre_ip}")
            emre_machine.fail(f"ping -c 2 -W 1 {um_ip}")

            emre_machine.wait_until_succeeds(f"ping -c 2 {ssh_target_ip}")
            emre_machine.succeed(f"ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 {ssh_target_ip} true")
            um_machine.fail(f"ping -c 2 -W 1 {ssh_target_ip}")

            # Test Shared Server Isolation
            # Incoming SSH should work (Tag:shared-server is in 'dst' of SSH ACL)
            emre_machine.wait_until_succeeds(f"ping -c 2 {server_ip}")

            cmd = f"ssh -vvv -o StrictHostKeyChecking=no -o ConnectTimeout=5 {server_ip} true"
            code, output = emre_machine.execute(cmd, timeout=30)
            if code != 0:
                print(f"SSH failed with code {code}. Output:\n{output}")
                print("Shared Server Tailscaled Logs:")
                print(shared_server.execute("journalctl -u tailscaled --no-pager -n 100")[1])
                raise Exception(f"SSH failed with code {code}")

            # Outgoing Traffic should FAIL (Tag:shared-server is NOT in 'src' of any ACL)
            shared_server.fail(f"ping -c 2 -W 1 {emre_ip}")
            shared_server.fail(f"ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 {emre_ip} true")
            shared_server.fail(f"ping -c 2 -W 1 {emre_ip}")
            shared_server.fail(f"ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 {emre_ip} true")

            print("ALL VERIFICATIONS PASSED")
          '';
        };
    };
}
