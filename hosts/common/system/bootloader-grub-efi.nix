{
  lib,
  grubDevice ? "nodev",
  efiInstallAsRemovable ? false,
  canTouchEfiVariables ? false,
  useOSProber ? true,
  ...
}:
{
  boot.loader = {
    grub = {
      enable = lib.mkDefault true;
      device = grubDevice;
      efiSupport = true;
      inherit efiInstallAsRemovable useOSProber;
      default = "saved";
      configurationLimit = 30;
    };
    efi.canTouchEfiVariables = canTouchEfiVariables;
  };
}
