{
  flake.modules.nixos.system-boot-grub =
    { lib, ... }:
    {
      boot.loader = {
        efi.canTouchEfiVariables = true;
        grub = {
          enable = lib.mkDefault true;
          efiSupport = true;
          efiInstallAsRemovable = false;
          device = "nodev";
          useOSProber = true;
          default = "saved";
          configurationLimit = 30;
        };
      };
    };
}
