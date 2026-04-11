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
      };

      networking.useDHCP = lib.mkDefault true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
