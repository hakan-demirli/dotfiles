{
  flake.modules.nixos.system-impermanence =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.system.impermanence;
    in
    {
      options.system.impermanence = {
        username = lib.mkOption {
          type = lib.types.str;
          default = "emre";
        };
        uid = lib.mkOption {
          type = lib.types.int;
          default = 1000;
        };
        persistentDirs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        persistentUserDirs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "Desktop"
            "Documents"
            "Downloads"
            "Videos"
          ];
          description = "User directories to persist (relative to home)";
        };
      };

      config = {
        boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
          mkdir /btrfs_tmp
          mount /dev/root_vg/root /btrfs_tmp
          if [[ -e /btrfs_tmp/root ]]; then
              mkdir -p /btrfs_tmp/old_roots
              timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
              mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
          fi

          delete_subvolume_recursively() {
              IFS=$'\n'
              for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
                  delete_subvolume_recursively "/btrfs_tmp/$i"
              done
              btrfs subvolume delete "$1"
          }

          for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +15); do
              delete_subvolume_recursively "$i"
          done

          btrfs subvolume create /btrfs_tmp/root
          umount /btrfs_tmp
        '';

        fileSystems."/persist".neededForBoot = true;

        environment.persistence."/persist/system" = {
          hideMounts = true;
          directories = [
            "/var/lib/nixos"
            "/var/lib/systemd/coredump"
            "/etc/NetworkManager/system-connections"
            "/root/.cache/nix"
          ]
          ++ cfg.persistentDirs;
        };

        environment.persistence."/persist" = {
          hideMounts = true;
          users.${cfg.username} = {
            directories = cfg.persistentUserDirs;
          };
        };

        systemd.tmpfiles.rules = [
          "d /persist/home/ 0777 root root -"
          "d /persist/home/${cfg.username} 0700 ${toString cfg.uid} users -"
        ];
      };
    };
}
