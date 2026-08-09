{
  id = "router-0";
  hostname = "router-0";
  deployment_roles = [ ];
  topology_roles = [ "external" ];
  state = "provisioned";

  location.kind = "workstation";

  ownership = {
    class = "personal";
    owner = "user-0";
    operator = "user-0";
    custodian = "user-0";
  };

  hardware = {
    cpu_vendor = "mediatek";
    cpu_sockets = 1;
    cpu_cores_per_socket = 4;
    cpu_threads_per_core = 1;
    cpu_model = "MediaTek MT7987A";
    ram_mib = 1024;
    arch = "aarch64-linux";
    os = "openwrt";
    chassis = "GL.iNet GL-BE10000 (Slate 7)";
  };

  monitoring = {
    enabled = false;
    always_on = false;
  };

  labels = {
    device_type = "openwrt-be10000";
    tailscale_tag = "tag:router";
    tailscale_login_server = "sshr.polarbearvuzi.com";
    lan_cidr = "192.168.69.0/24";
    lan_ip = "192.168.69.1";
    wifi_wan = "true";
  };
}
