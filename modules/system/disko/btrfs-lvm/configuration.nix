{
  flake.modules.nixos.system-disko-btrfs-lvm =
    { config, lib, ... }:
    let
      cfg = config.system.disko;
      additionalDiskConfigs = lib.listToAttrs (
        lib.imap0 (
          idx: diskPath:
          lib.nameValuePair "extra${toString idx}" {
            device = diskPath;
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                primary = {
                  size = "100%";
                  content = {
                    type = "lvm_pv";
                    vg = "root_vg";
                  };
                };
              };
            };
          }
        ) cfg.additionalDisks
      );
    in
    {
      options.system.disko = {
        device = lib.mkOption { type = lib.types.str; };
        swapSize = lib.mkOption { type = lib.types.str; };
        additionalDisks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional disks to add to the LVM volume group for expanded storage";
        };
      };
      config = {
        disko.devices = {
          disk = {
            main = {
              inherit (cfg) device;
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
                    size = cfg.swapSize;
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
          }
          // additionalDiskConfigs;
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
