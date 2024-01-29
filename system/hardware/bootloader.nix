{...}: {
  # Bootloader.
  boot.loader = {
    grub = {
      enable = true;
      device = "nodev";
      useOSProber = true;
      efiSupport = true;
      default = "saved";
      configurationLimit = 30;
    };
    efi.canTouchEfiVariables = true;
  };
}
