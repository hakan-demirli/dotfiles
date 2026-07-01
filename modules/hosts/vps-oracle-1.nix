{ lib, ... }:
{
  users.users.emre.hashedPassword = "$6$hjsD4y4Iy/9ql6dC$WYxNpnvlx9r6TbGwWcXMqzzsyzh6IvftawYlyvwB4/Zr21UNO5eyj87WB2JqcH.EoO3rmP10P5X/d0b6tNcSh/";

  services.qemuGuest.enable = true;

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "usbhid"
    ];
    initrd.kernelModules = [ "dm-snapshot" ];
    loader.efi.canTouchEfiVariables = true;
    loader.grub.efiInstallAsRemovable = false;
  };

  networking = {
    useDHCP = lib.mkDefault true;
    interfaces.enp1s0.useDHCP = lib.mkDefault true;
  };
}
