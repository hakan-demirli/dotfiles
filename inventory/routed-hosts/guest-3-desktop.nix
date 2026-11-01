{
  id = "guest-3-desktop";
  description = "Desktop that guest-3 owns and manages on the router-0 LAN";
  network = "router-0-lan";
  ipv4 = "192.168.69.231";
  access.users = [
    {
      user = "guest-3";
      ports = [ 22 ];
    }
  ];
}
