{
  flake.modules.nixos.laptop-hardware =
    { lib, config, ... }:
    {
      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "nvme"
          "ahci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
        initrd.kernelModules = [ ];
        kernelModules = [ "kvm-amd" ];
        extraModulePackages = [ ];
      };

      fileSystems = {
        "/mnt/second" = {
          device = "/dev/disk/by-uuid/120CC7A90CC785E7";
          fsType = "ntfs-3g";
          options = [
            "rw"
            "uid=1000"
          ];
        };

        "/mnt/third" = {
          device = "/dev/disk/by-uuid/676ca51a-3db9-46fb-9b09-b4edb9a3f795";
          fsType = "btrfs";
        };
      };

      networking.useDHCP = lib.mkDefault true;
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
