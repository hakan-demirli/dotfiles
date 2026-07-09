{
  id = "vps-oracle-0";
  roles = [
    "cloud-vps-control"
    "mgmt-observability"
  ];
  state = "provisioned";

  location = {
    kind = "cloud-vm";
    provider = "oracle";
  };

  ownership = {
    class = "leased";
    owner = "user-0";
    operator = "user-0";
    custodian = "user-0";
  };

  hardware = {
    arch = "aarch64-linux";
    cpu_vendor = "ampere";
    cpu_sockets = 1;
    cpu_cores_per_socket = 4;
    cpu_threads_per_core = 1;
    ram_gib = 24;
  };

  disko = {
    root_disk = "/dev/sda";
    layout = "btrfs-lvm";
    managed = true;
    swap_size = "1G";
  };

  impermanence = {
    enable = true;
    rollback_backend = "btrfs";
    persisted_paths = [
      "/var/lib/libvirt"
      "/var/log"
    ];
  };

  keys = {
    ssh = [ ];
    age = [ "age1vueyy3uza38kwlpgdzexpcmeru44lxcwku3t7pzzcdaqcldn6vwsu8a32u" ];
  };

  labels = {
    services = "headscale,reverse-ssh,slurm-master,ntfy,homepage,jellyfin,transmission,harmonia,victoriametrics,grafana";
    nix_cache_public_key = "binary-cache-key:YUqGpOpjoO0zIREJVH0PAdjy9L3DWi917Z8/eFqQqy8=";
  };
}
