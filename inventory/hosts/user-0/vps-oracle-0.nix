{
  id = "vps-oracle-0";
  deployment_roles = [
    "cloud-vps-control"
    "mgmt-observability"
  ];
  topology_roles = [
    "controller"
    "mgmt"
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
    ram_mib = 24576;
  };

  disko = {
    root_disk = "/dev/oracleoci/oraclevda";
    layout = "btrfs-lvm";
    managed = true;
    swap_size = "8G";
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
    age = [ "age1lrl3rcvqg4y8nmj32arjgagycwghxrnfmw69v43jjep78evv9pmqugdkxj" ];
  };

  labels = {
    services = "headscale,reverse-ssh,slurm-master,ntfy,homepage,jellyfin,transmission,harmonia,victoriametrics,grafana";
    nix_cache_public_key = "binary-cache-key:YUqGpOpjoO0zIREJVH0PAdjy9L3DWi917Z8/eFqQqy8=";
  };
}
