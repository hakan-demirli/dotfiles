{ lib, ... }:
{
  services.qemuGuest.enable = true;

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "sd_mod"
      "usbhid"
    ];
    initrd.kernelModules = [ "dm-snapshot" ];
    loader.efi.canTouchEfiVariables = true;
  };

  networking.useDHCP = lib.mkDefault true;
}
