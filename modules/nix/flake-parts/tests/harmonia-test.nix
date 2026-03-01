_: {
  perSystem =
    { config, pkgs, ... }:
    {
      apps.test-harmonia = {
        type = "app";
        program = "${config.packages.harmonia-test.driver}/bin/nixos-test-driver";
        meta.description = "Run the Harmonia binary cache integration test";
      };

      packages.harmonia-test =
        let
          testFile = pkgs.writeText "hello-cache" "hello from harmonia";
        in
        pkgs.testers.runNixOSTest {
          name = "harmonia-test";

          nodes = {
            cache_server =
              { pkgs, ... }:
              {
                services.harmonia = {
                  enable = true;
                  signKeyPaths = [ "/var/lib/harmonia/signing-key.secret" ];
                  settings.bind = "[::]:5000";
                };

                systemd.services.harmonia-keygen = {
                  description = "Generate Harmonia signing key";
                  wantedBy = [ "multi-user.target" ];
                  before = [ "harmonia.service" ];
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                  };
                  script = ''
                    mkdir -p /var/lib/harmonia
                    if [ ! -f /var/lib/harmonia/signing-key.secret ]; then
                      ${pkgs.nix}/bin/nix-store \
                        --generate-binary-cache-key \
                        harmonia-test-1 \
                        /var/lib/harmonia/signing-key.secret \
                        /var/lib/harmonia/signing-key.pub
                    fi
                  '';
                };

                networking.firewall.allowedTCPPorts = [ 5000 ];

                environment.systemPackages = [ pkgs.nix ];

                nix.settings.allowed-users = [ "*" ];

                system.extraDependencies = [ testFile ];
              };

            client =
              { lib, ... }:
              {
                nix.settings = {
                  require-sigs = false;
                  substituters = lib.mkForce [ "http://cache_server:5000" ];
                  experimental-features = [
                    "nix-command"
                    "flakes"
                  ];
                };
              };
          };

          testScript =
            let
              hashPart = pkg: builtins.substring (builtins.stringLength builtins.storeDir + 1) 32 pkg.outPath;
            in
            ''
              start_all()

              cache_server.wait_for_unit("harmonia-keygen.service")
              cache_server.wait_for_unit("harmonia.service")
              cache_server.wait_for_open_port(5000)

              cache_server.succeed("curl -sf http://localhost:5000/nix-cache-info | grep 'StoreDir: /nix/store'")

              pub_key = cache_server.succeed("cat /var/lib/harmonia/signing-key.pub").strip()
              print(f"Cache public key: {pub_key}")

              narinfo = cache_server.succeed("curl -sf http://localhost:5000/${hashPart testFile}.narinfo")
              print(f"narinfo: {narinfo}")
              assert "StorePath: ${testFile}" in narinfo, "StorePath not found in narinfo"
              assert "Sig: harmonia-test-1:" in narinfo, "Signature not found in narinfo"

              client.wait_until_succeeds("curl -sf http://cache_server:5000/nix-cache-info")
              client.succeed("nix copy --from http://cache_server:5000/ ${testFile}")
              client.succeed("grep 'hello from harmonia' ${testFile}")

              print("ALL VERIFICATIONS PASSED")
            '';
        };
    };
}
