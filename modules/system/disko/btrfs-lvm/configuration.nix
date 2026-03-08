{
  flake.modules.nixos.system-disko-btrfs-lvm =
    { config, lib, ... }:
    let
      cfg = config.system.disko;
      mkDevices = import ./_devices.nix;
    in
    {
      options.system.disko = {
        device = lib.mkOption { type = lib.types.str; };
        swapSize = lib.mkOption { type = lib.types.str; };
        additionalDisks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional disks to add to the LVM volume group for expanded storage";
        };
      };

      config = {
        disko.devices = mkDevices {
          inherit lib;
          inherit (cfg) device swapSize additionalDisks;
        };
      };
    };
}
