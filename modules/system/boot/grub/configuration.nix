{
  flake.modules.nixos.system-boot-grub = { config, lib, ... }: {
    boot.loader = {
      grub = {
        enable = lib.mkDefault true;
        efiSupport = true;
        default = "saved";
        configurationLimit = 30;
      };
    };
  };
}
