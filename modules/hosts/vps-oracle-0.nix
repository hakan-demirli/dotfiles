{ lib, ... }:
{
  time.timeZone = "Europe/Zurich";

  services = {
    qemuGuest.enable = true;
    udev.extraRules = ''
      KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_VENDOR}=="ORACLE", ENV{ID_MODEL}=="BlockVolume", ENV{ID_PATH}=="*:1", SYMLINK+="oracleoci/oraclevda"
      KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_VENDOR}=="ORACLE", ENV{ID_MODEL}=="BlockVolume", ENV{ID_PATH}=="*:1", SYMLINK+="oracleoci/oraclevda%n"
    '';
    reverse-ssh-server.allowedTCPPorts = [
      22
      80
      443
    ];
  };

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

}
