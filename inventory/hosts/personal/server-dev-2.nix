{
  id = "server-dev-2";
  roles = [ "personal-server-dev" ];
  state = "provisioned";
  slurm_features = [
    "intel"
    "workstation"
    "fpga-vivado"
  ];
  slurm_weight = 100;

  location.kind = "workstation";

  ownership = {
    class = "borrowed";
    owner = "user-0";
    operator = "user-0";
    custodian = "user-0";
  };

  hardware = {
    cpu_vendor = "intel";
    cpu_sockets = 1;
    cpu_cores_per_socket = 12;
    cpu_threads_per_core = 2;
    cpu_logical_count = 20;
    cpu_model = "12th Gen Intel(R) Core(TM) i7-12700";
    ram_gib = 32;
    arch = "x86_64-linux";
  };

  disko = {
    root_disk = "/dev/disk/by-id/nvme-SK_hynix_BC711_HFM512GD3JX013N_FYC6N012211306C69";
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
      "/persist/xilinx"
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
