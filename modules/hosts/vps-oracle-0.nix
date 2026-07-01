{ lib, ... }:
{
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
