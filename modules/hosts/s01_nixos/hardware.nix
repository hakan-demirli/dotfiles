{
  flake.modules.nixos.s01-hardware =
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

      networking.useDHCP = lib.mkDefault true;
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
