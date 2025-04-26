{
  pkgs,
  username ? "emre",
  uid ? 1000,
  persistentDirs ? [ ],
  ...
}:

let
  defaultPersistentDirs = [
    "/var/log"
    "/var/lib/nixos"
    "/var/lib/systemd/coredump"
    "/etc/NetworkManager/system-connections"
    "/var/lib/bluetooth"
  ];

  allPersistentDirs = defaultPersistentDirs ++ persistentDirs;
in
{
  boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
    mkdir -p /btrfs_tmp # Use a more specific name
    mount /dev/root_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        # Check if it's actually a subvolume, not just a directory
        if btrfs subvolume list -o /btrfs_tmp/root >/dev/null 2>&1; then
          echo "Moving existing BTRFS root subvolume to snapshots..."
          mkdir -p /btrfs_tmp/old_roots
          timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%d_%H:%M:%S")
          # Use a read-only snapshot for safety? Maybe later. Simple move for now.
          mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
        else
          echo "Warning: /btrfs_tmp/root exists but is not a BTRFS subvolume. Removing."
          rm -rf /btrfs_tmp/root
        fi
    fi

    # Recursive delete function for BTRFS subvolumes
    delete_subvolume_recursively() {
        local target_subvol=$1
        # Ensure path safety (basic)
        if [[ "$target_subvol" != "/btrfs_tmp/old_roots/"* ]]; then
            echo "Error: Refusing to delete subvolume outside /btrfs_tmp/old_roots/: $target_subvol"
            return 1
        fi
        echo "Deleting subvolume recursively: $target_subvol"
        # List direct child subvolumes relative to the mount point
        local subvol_path_relative_to_mount=$(echo "$target_subvol" | sed 's|^/btrfs_tmp/||')
        IFS=$'\n'
        for sub in $(btrfs subvolume list -o "$target_subvol" | cut -f 9- -d ' '); do
             # Need the full path for recursive call
            delete_subvolume_recursively "/btrfs_tmp/$sub"
        done
        # Delete the parent subvolume itself
        if btrfs subvolume show "$target_subvol" >/dev/null 2>&1; then
            btrfs subvolume delete "$target_subvol" || echo "Failed to delete subvolume $target_subvol"
        else
             echo "Subvolume $target_subvol seems to be already gone or is not a subvolume."
        fi
    }

    # Clean up snapshots older than 30 days
    echo "Cleaning up old root snapshots..."
    find /btrfs_tmp/old_roots/ -maxdepth 1 -type d -mtime +30 | while read -r old_root; do
      # Ensure it's likely a snapshot directory (basic check)
      if [[ "$old_root" =~ /btrfs_tmp/old_roots/[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
         delete_subvolume_recursively "$old_root"
      fi
    done

    # Create the new root subvolume if it doesn't exist
    if ! btrfs subvolume show /btrfs_tmp/root >/dev/null 2>&1; then
       echo "Creating new BTRFS root subvolume..."
       btrfs subvolume create /btrfs_tmp/root
    fi
    umount /btrfs_tmp
    echo "BTRFS root subvolume setup complete."
  '';

  fileSystems."/persist" = {
    device = "/dev/root_vg/root";
    fsType = "btrfs";
    options = [
      "subvol=persist"
      "compress=zstd"
      "noatime"
    ];
    neededForBoot = true;
  };

  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = allPersistentDirs;
  };

  systemd.tmpfiles.rules = [
    "d /persist/home 0755 root root -"
    "d /persist/home/${username} 0700 ${toString uid} users -"
    "d /home/${username} 0700 ${toString uid} users -"
  ];

  environment.persistence."/persist/home/${username}" = {
    directories = [
      { directory = "/home/${username}"; }
    ];
    files = [
    ];
  };
}
