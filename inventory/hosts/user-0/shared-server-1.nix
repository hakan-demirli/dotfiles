{
  id = "shared-server-1";
  deployment_roles = [
    "fpga"
    "shared-server"
  ];
  topology_roles = [ "login" ];
  state = "provisioned";

  location.kind = "workstation";

  ownership = {
    class = "borrowed";
    owner = "user-0";
    operator = "user-0";
    custodian = "user-0";
  };

  hardware = {
    cpu_vendor = "amd";
    cpu_sockets = 1;
    cpu_cores_per_socket = 6;
    cpu_threads_per_core = 2;
    cpu_model = "AMD Ryzen 5 PRO 5655G with Radeon Graphics";
    ram_mib = 16384;
    arch = "x86_64-linux";
    gpu = "amd";
    vendor = "csl-computer";
    chassis = "CSL Computer GmbH V28988";
    fpgas = [
      {
        vendor = "amd";
        model = "Alveo V80 PQ";
        part = "A-V80-P64G-PQ-G";
        serial = "XFL1Y0K0FUV3";
        pci_bdf = "0000:01:00.0";
        parent_pci_bdf = "0000:00:01.1";
        pci_id = "10ee:50b4";
      }
    ];
  };

  boot.efi_registration = "fallback";

  disko = {
    root_disk = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_25422J805576";
    layout = "btrfs-lvm";
    managed = true;
    swap_size = "32G";
  };

  impermanence = {
    enable = true;
    rollback_backend = "btrfs";
    home_mode = "user-managed";
    persisted_paths = [
      "/var/lib/docker"
      "/var/lib/systemd/pstore"
      "/var/log"
    ];
  };

  monitoring = {
    enabled = true;
    always_on = true;
    exporters = [ "node" ];
  };

  labels = {
    tailscale_auth_key = "false";
  };
}
