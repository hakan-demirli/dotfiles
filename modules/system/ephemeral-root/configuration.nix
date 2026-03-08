{
  flake.modules.nixos.system-ephemeral-root = _: {
    boot.initrd = {
      systemd.enable = true;
      supportedFilesystems = [ "btrfs" ];
      systemd.services.rollback-root = {
        description = "Rollback btrfs root to blank snapshot";
        wantedBy = [ "initrd.target" ];
        after = [ "dev-root_vg-root.device" ];
        before = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          mkdir -p /mnt
          mount -t btrfs -o subvol=/ /dev/root_vg/root /mnt

          if [[ -e /mnt/root ]]; then
            btrfs subvolume list -o /mnt/root | cut -f9 -d' ' | while read subvol; do
              btrfs subvolume delete "/mnt/$subvol"
            done
            btrfs subvolume delete /mnt/root
          fi

          btrfs subvolume snapshot /mnt/root-blank /mnt/root
          umount /mnt
        '';
      };
    };
  };
}
