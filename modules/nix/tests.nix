{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      testSuite = import ./checks/lib {
        inherit pkgs lib;
        inherit (inputs) self;
      };

      inventory = inputs.self.lib.inventory;
    in
    {
      checks = {
        fleet-eval =
          pkgs.runCommand "infra-personal-fleet-eval-stamp"
            {
              hostCount = toString (lib.length (lib.attrNames inventory.hosts));
              roleCount = toString (lib.length (lib.attrNames inventory.roles));
              clusterCount = toString (lib.length (lib.attrNames inventory.clusters));
              teamCount = toString (lib.length (lib.attrNames inventory.teams));
              tierCount = toString (lib.length (lib.attrNames inventory.accessTiers));
              userCount = toString (lib.length (lib.attrNames inventory.users));
            }
            ''
              {
                echo "hosts=$hostCount"
                echo "roles=$roleCount"
                echo "clusters=$clusterCount"
                echo "teams=$teamCount"
                echo "tiers=$tierCount"
                echo "users=$userCount"
              } > $out
            '';
      }
      // (lib.mapAttrs' (name: drv: lib.nameValuePair "test-${name}" drv) testSuite);

      apps = lib.mapAttrs' (
        name: drv:
        lib.nameValuePair "test-${name}" {
          type = "app";
          meta.description =
            if drv ? driver then
              "Run NixOS VM test ${name} via the interactive test driver"
            else
              "Build the ${name} check derivation";
          program =
            if drv ? driver then
              "${drv.driver}/bin/nixos-test-driver"
            else
              toString (
                pkgs.writeShellScript "run-test-${name}" ''
                  exec ${pkgs.nix}/bin/nix build --no-link --print-out-paths \
                    "${inputs.self}#checks.${system}.test-${name}"
                ''
              );
        }
      ) testSuite;
    };
}
