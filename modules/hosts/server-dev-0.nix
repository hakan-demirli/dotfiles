{ lib, ... }:
{
  users.users.emre.hashedPassword = "$6$hjsD4y4Iy/9ql6dC$WYxNpnvlx9r6TbGwWcXMqzzsyzh6IvftawYlyvwB4/Zr21UNO5eyj87WB2JqcH.EoO3rmP10P5X/d0b6tNcSh/";

  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
  };

  programs.nix-ld.enable = true;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  system.impermanence.extraPersistentUserDirs = [
    ".config/sunshine"
  ];

  services.remotedesktop = {
    modeOverride = "headless";
    connector = "DP-1";
    resolution = "1920x1080@60";
    edidBase64 = "AP///////wBMg6pBAAAAAAAgAQS1HhN4A8/RrlE+tiMLUFQAAAABAQEBAQEBAQEBAQEBAQEBy/5AZLAIGHAgCIgALr0QAAAby/5AZLAIyHogCIgALr0QAAAbAAAA/QAweNraQgEAAAAAAAAAAAAAAgABAAAZlsg6FUbIAAAAAT1wIHkCACAADLpBWapBAAAAAAAWACEAHbgLbAdACwgHAO7qUOzTtj1CCwFFVEBe0GAYECN4JgAJBwYDAAAAUAAAIgAU5/MJhT8LYwAfAAcABwcXAAcABwCBAB9zGgAAAwMweACgdAJgAngAAAAAjeMFgADmBgUBdGACAAAAAAAJkA==";
  };
}
