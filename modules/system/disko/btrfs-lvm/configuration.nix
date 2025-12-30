{
  flake.modules.nixos.system-disko-btrfs-lvm =
    { config, lib, ... }:
    {
      options.system.disko = {
        device = lib.mkOption { type = lib.types.str; };
        swapSize = lib.mkOption { type = lib.types.str; };
      };
      config = {
        disko.devices = {
          disk.main = {
            inherit (config.system.disko) device;
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                boot = {
                  name = "boot";
                  size = "1M";
                  type = "EF02";
                };
                esp = {
                  name = "ESP";
                  size = "500M";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                  };
                };
                swap = {
                  size = config.system.disko.swapSize;
                  content = {
                    type = "swap";
                    resumeDevice = true;
                  };
                };
                root = {
                  name = "root";
                  size = "100%";
                  content = {
                    type = "lvm_pv";
                    vg = "root_vg";
                  };
                };
              };
            };
          };
          lvm_vg = {
            root_vg = {
              type = "lvm_vg";
              lvs = {
                root = {
                  size = "100%FREE";
                  content = {
                    type = "btrfs";
                    extraArgs = [ "-f" ];

                    subvolumes = {
                      "/root" = {
                        mountpoint = "/";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "/nix" = {
                        mountpoint = "/nix";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };
                      "/persist" = {
                        mountpoint = "/persist";
                        mountOptions = [
                          "compress=zstd"
                          "noatime"
                        ];
                      };

                    };
                  };
                };
              };
            };
          };
        };
      };
    };
}
