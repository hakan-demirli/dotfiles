{
  flake.modules.nixos.system-boot-grub =
    { lib, ... }:
    {
      boot.loader = {
        grub = {
          enable = lib.mkDefault true;
          efiSupport = true;
          device = "nodev";
          useOSProber = true;
          default = "saved";
          configurationLimit = 30;
        };
      };
    };
}
