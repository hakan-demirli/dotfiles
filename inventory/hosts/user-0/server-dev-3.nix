{
  id = "server-dev-3";
  deployment_roles = [ "server-dev" ];
  topology_roles = [ "compute" ];
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
    chassis = "Framework Desktop";
    cpu_vendor = "amd";
    cpu_sockets = 1;
    cpu_cores_per_socket = 16;
    cpu_threads_per_core = 2;
    cpu_model = "AMD Ryzen AI MAX+ 395 with Radeon 8060S";
    ram_mib = 131072;
    arch = "x86_64-linux";
    gpu = "amd";
  };

  disko = {
    root_disk = "/dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_2548GE400033";
    layout = "btrfs-lvm";
    managed = true;
    swap_size = "32G";
  };

  impermanence = {
    enable = true;
    rollback_backend = "btrfs";
    home_mode = "user-managed";
    persisted_paths = [
      "/var/lib/libvirt"
      "/var/log"
    ];
  };

  labels = {
    tailscale_authority = "true";
    nixos_hardware = "framework/desktop/amd-ai-max-300-series";
  };

  monitoring = {
    enabled = true;
    exporters = [
      "node"
      "smartctl"
    ];
  };
}
