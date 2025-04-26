{
  grubDevice ? "nodev",
  efiInstallAsRemovable ? false,
  canTouchEfiVariables ? false,
  useOSProber ? true,
  ...
}:
{
  boot.loader = {
    grub = {
      enable = true;
      device = grubDevice;
      efiSupport = true;
      inherit efiInstallAsRemovable useOSProber;
      default = "saved";
      configurationLimit = 30;
    };
    efi.canTouchEfiVariables = canTouchEfiVariables;
  };
}
