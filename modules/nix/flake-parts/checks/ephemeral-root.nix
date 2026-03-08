{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      diskoLib = inputs.disko.lib;
      mkDevices = import ../../../system/disko/btrfs-lvm/_devices.nix;

      diskoConfig = {
        disko.devices = mkDevices {
          inherit lib;
          device = "/dev/vda";
          swapSize = "1G";
        };
      };
    in
    lib.optionalAttrs (lib.hasSuffix "-linux" system) {
      checks.ephemeral-root = diskoLib.testLib.makeDiskoTest {
        inherit pkgs;
        name = "ephemeral-root";
        disko-config = diskoConfig;
        testMode = "module";

        extraSystemConfig = {
          imports = [
            inputs.self.modules.nixos.system-ephemeral-root
            inputs.impermanence.nixosModules.impermanence
          ];

          fileSystems."/persist".neededForBoot = true;

          environment.persistence."/persist" = {
            hideMounts = true;
            directories = [
              "/var/lib/nixos"
              "/var/lib/test-persist"
            ];
          };

          environment.systemPackages = [ pkgs.btrfs-progs ];

          system.stateVersion = "24.11";
        };

        extraTestScript = ''
          machine.succeed("btrfs subvolume list / | grep -q 'path root$'")
          machine.succeed("btrfs subvolume list / | grep -q 'path root-blank$'")
          machine.succeed("btrfs subvolume list / | grep -q 'path nix$'")
          machine.succeed("btrfs subvolume list / | grep -q 'path persist$'")

          machine.succeed("mountpoint /persist")

          machine.succeed("mkdir -p /var/lib/test-persist")
          machine.succeed("echo 'persist-data' > /var/lib/test-persist/testfile")

          machine.succeed("echo 'ephemeral-data' > /ephemeral-testfile")

          machine.shutdown()
          machine.start()
          machine.wait_for_unit("multi-user.target")

          machine.succeed("test -f /var/lib/test-persist/testfile")
          machine.succeed("grep -q 'persist-data' /var/lib/test-persist/testfile")

          machine.fail("test -f /ephemeral-testfile")

          print("Ephemeral root test passed!")
        '';
      };
    };
}
