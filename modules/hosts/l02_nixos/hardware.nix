{
  flake.modules.nixos.l02-hardware =
    { lib, config, ... }:
    {
      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "thunderbolt"
          "nvme"
          "usb_storage"
          "sd_mod"
        ];
        initrd.kernelModules = [ ];
        kernelModules = [
          "kvm-intel"
          "intel_ishtp_hid"
        ];
        extraModulePackages = [ ];
      };

      networking.useDHCP = lib.mkDefault true;

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      hardware.sensor.iio.enable = true;
    };
}
