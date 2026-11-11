{
  id = "server-dev-1";
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
    cpu_vendor = "amd";
    cpu_sockets = 1;
    cpu_cores_per_socket = 16;
    cpu_threads_per_core = 2;
    cpu_model = "AMD Ryzen 9 7945HX with Radeon Graphics";
    ram_mib = 65536;
    arch = "x86_64-linux";
    gpu = "amd";
    mainboard = "minisforum-ms-a2";
  };

  disko = {
    root_disk = "/dev/disk/by-id/nvme-SAMSUNG_MZ1L23T8HBLA-00A07_S667NT0WB01649";
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
    ssh_host_ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMfqZxQGb87zyV1Oie/HLTa43MCU5BIe7oGfLqE7dXss";
  };

  monitoring = {
    enabled = true;
    exporters = [
      "node"
      "smartctl"
    ];
  };

  deploy.hold = {
    reason = "ssd swap";
    until = "2026-11-12";
  };
}
