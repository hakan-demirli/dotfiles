{ lib, ... }:
{
  users.users.emre.hashedPassword = "$6$hjsD4y4Iy/9ql6dC$WYxNpnvlx9r6TbGwWcXMqzzsyzh6IvftawYlyvwB4/Zr21UNO5eyj87WB2JqcH.EoO3rmP10P5X/d0b6tNcSh/";

  networking = {
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
  };

  programs.nix-ld.enable = true;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  fileSystems = {
    "/mnt/hdd1" = {
      device = "/dev/disk/by-uuid/bc61c6f2-683e-4d24-9ad7-f76debff7d90";
      fsType = "btrfs";
      options = [
        "compress=zstd"
        "autodefrag"
        "noatime"
        "nofail"
      ];
    };
    "/mnt/hdd2" = {
      device = "/dev/disk/by-uuid/27feb42b-4406-4e68-ba6f-b29cb9d12d75";
      fsType = "btrfs";
      options = [
        "compress=zstd"
        "autodefrag"
        "noatime"
        "nofail"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/hdd1 0775 emre users -"
    "d /mnt/hdd2 0775 emre users -"
  ];
}
