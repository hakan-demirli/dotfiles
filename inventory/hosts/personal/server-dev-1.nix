{
  id = "server-dev-1";
  roles = [ "personal-server-dev" ];
  state = "provisioned";
  slurm_features = [
    "amd"
    "workstation"
  ];
  slurm_weight = 100;

  location.kind = "workstation";

  ownership = {
    class = "personal";
    owner = "user-0";
    operator = "user-0";
    custodian = "user-0";
  };

  hardware = {
    cpu_vendor = "amd";
    cpu_sockets = 1;
    cpu_cores_per_socket = 16;
    cpu_threads_per_core = 2;
    cpu_model = "AMD Ryzen 9 7945HX with Radeon Graphics";
    ram_gib = 64;
    arch = "x86_64-linux";
    gpu = "amd";
  };

  disko = {
    root_disk = "/dev/disk/by-id/nvme-Lexar_SSD_NM790_4TB_QKP899R000033P2202";
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
    ];
  };

  labels = {
    tailscale_authority = "true";
  };

  monitoring = {
    enabled = true;
    exporters = [
      "node"
      "smartctl"
    ];
  };
}
