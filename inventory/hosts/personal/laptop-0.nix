{
  id = "laptop-0";
  roles = [ "personal-laptop" ];
  state = "provisioned";
  slurm_features = [
    "amd"
    "gpu-nvidia"
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
    cpu_vendor = "amd";
    cpu_sockets = 1;
    cpu_cores_per_socket = 8;
    cpu_threads_per_core = 2;
    cpu_model = "AMD Ryzen 7 4800H with Radeon Graphics";
    ram_gib = 24;
    arch = "x86_64-linux";
    gpu = "amd+nvidia";
  };

  disko = {
    root_disk = "/dev/disk/by-id/nvme-KIOXIA-EXCERIA_SSD_X26FC0ZVF4M3";
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
    ];
  };

  labels = {
    sunshine = "true";
    gpu_amd_bus_id = "PCI:6:0:0";
    gpu_nvidia_bus_id = "PCI:1:0:0";
    hibernation = "true";
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
