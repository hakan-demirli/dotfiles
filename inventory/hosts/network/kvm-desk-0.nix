{
  id = "kvm-desk-0";
  hostname = "kvm-desk-0";
  roles = [ ];
  state = "provisioned";

  location.kind = "workstation";

  ownership = {
    class = "personal";
    owner = "user-0";
    operator = "user-0";
    custodian = "user-0";
  };

  hardware = {
    cpu_vendor = "axera";
    cpu_sockets = 1;
    cpu_cores_per_socket = 2;
    cpu_threads_per_core = 1;
    cpu_model = "Axera AX630C (2xCortex-A53 @ 1.2GHz)";
    ram_mib = 1024;
    arch = "aarch64-linux";
    os = "ubuntu";
    chassis = "Sipeed NanoKVM-Pro Desk";
  };

  monitoring = {
    enabled = false;
    always_on = false;
  };

  labels = {
    device_type = "sipeed-nanokvm-pro-desk";
    device_role = "kvm-oob";
    firmware_version = "1.2.15";
    controls_host = "server-dev-1";
    tailscale_tag = "tag:kvm";
    tailscale_login_server = "sshr.polarbearvuzi.com";
    lan_cidr = "192.168.69.0/24";
    lan_ip = "192.168.69.10";
    web_port = "443";
    ssh_default_user = "root";
    kvm_framework = "nanokvm";
  };
}
