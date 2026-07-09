{ lib, ... }:
{
  users.users.emre.hashedPassword = "$6$hjsD4y4Iy/9ql6dC$WYxNpnvlx9r6TbGwWcXMqzzsyzh6IvftawYlyvwB4/Zr21UNO5eyj87WB2JqcH.EoO3rmP10P5X/d0b6tNcSh/";

  time.timeZone = "Europe/Zurich";

  services.qemuGuest.enable = true;

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "usbhid"
    ];
    initrd.kernelModules = [ "dm-snapshot" ];
    binfmt.emulatedSystems = [
      "x86_64-linux"
      "riscv64-linux"
    ];
    loader.efi.canTouchEfiVariables = true;
    loader.grub.efiInstallAsRemovable = false;
  };

  networking.useDHCP = lib.mkDefault true;

  services.reverse-ssh-server.allowedTCPPorts = [
    22
    80
    443
  ];
}
