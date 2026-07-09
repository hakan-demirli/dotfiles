{
  id = "laptop-1";
  roles = [ "personal-laptop" ];
  state = "provisioned";
  slurm_features = [
    "intel"
    "laptop"
  ];
  slurm_weight = 10;

  location.kind = "laptop";

  ownership = {
    class = "personal";
    owner = "user-0";
    operator = "user-0";
    custodian = "user-0";
  };

  hardware = {
    cpu_vendor = "intel";
    cpu_sockets = 1;
    cpu_cores_per_socket = 8;
    cpu_threads_per_core = 1;
    cpu_model = "Intel(R) Core(TM) Ultra 7 258V";
    ram_gib = 32;
    arch = "x86_64-linux";
    mainboard = "lunarlake-hp";
  };

  disko = {
    root_disk = "/dev/disk/by-id/nvme-PC_SN8000S_SDEPNRG-2T00-1006_25290K800525";
    layout = "btrfs-lvm";
    managed = true;
    swap_size = "32G";
  };

  impermanence = {
    enable = true;
    rollback_backend = "btrfs";
    persisted_paths = [
      "/var/lib/libvirt"
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/fprint"
    ];
  };

  labels = {
    vendor = "hp";
    hibernation = "true";
    fingerprint = "true";
    tablet = "true";
    tailscale_authority = "true";
  };

  monitoring = {
    enabled = true;
    always_on = false;
    exporters = [
      "node"
      "smartctl"
    ];
  };
}
