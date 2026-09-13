{
  managementPlatform = "l2-manager";
  dhcpOption43Override = false;

  snmp.enable = false;
  mirror.sessions = [ ];
  loopDetection.enable = true;
  lldp.enable = false;
  stp.enable = false;
  igmpSnooping.enable = false;

  dhcpSnooping = {
    enable = true;
    trustedPortSource = "uplink-discovery";
  };
}
