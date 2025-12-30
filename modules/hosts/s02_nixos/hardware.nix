{
  flake.modules.nixos.s02-hardware =
    { lib, config, ... }:
    {
      boot = {
        initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "ahci"
          "usbhid"
          "usb_storage"
          "sd_mod"
        ];
        initrd.kernelModules = [ "dm-snapshot" ];
        kernelModules = [ "kvm-amd" ];
        extraModulePackages = [ ];
      };

      fileSystems."/mnt/hdd1" = {
        device = "/dev/disk/by-uuid/bc61c6f2-683e-4d24-9ad7-f76debff7d90";
        fsType = "btrfs";
        options = [
          "compress=zstd"
          "autodefrag"
          "noatime"
          "nofail"
        ];
      };

      fileSystems."/mnt/hdd2" = {
        device = "/dev/disk/by-uuid/27feb42b-4406-4e68-ba6f-b29cb9d12d75";
        fsType = "btrfs";
        options = [
          "compress=zstd"
          "autodefrag"
          "noatime"
          "nofail"
        ];
      };

      systemd.tmpfiles.rules = [
        "d /mnt/hdd1 0775 emre users -"
        "d /mnt/hdd2 0775 emre users -"
      ];

      networking.useDHCP = lib.mkDefault true;
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
