{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "ahci"
    "usb_storage"
    "usbhid"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3d330da9-01ed-4bf1-baf5-0961bdf7afab";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/6054-B71B";
    fsType = "vfat";
  };

  # /dev/disk/by-uuid/0D11E693467F5A53 /mnt/second ntfs nosuid,nodev,nofail 0 0
  fileSystems."/mnt/second" = {
    device = "/dev/disk/by-uuid/0D11E693467F5A53";
    fsType = "ntfs-3g";
    # options = ["uid=1000" "gid=1000" "dmask=007" "fmask=117"];
    options = [
      "rw"
      "uid=1000"
    ];
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 30 * 1024;
    }
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp2s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp3s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
