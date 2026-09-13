{ lib, model }:
let
  ports = import ./ports.nix;
  hardening = import ./hardening.nix;

  unknownOverrides = lib.subtractLists model.ports (lib.attrNames ports.overrides);

  platforms = {
    auto = 0;
    gdms = 1;
    l3-manager = 2;
    l2-manager = 3;
  };

  trustedPortSources = [ "uplink-discovery" ];
in
assert lib.assertMsg (unknownOverrides == [ ])
  "switch-0: port overrides absent from ${model.model}: ${lib.concatStringsSep " " unknownOverrides}";
assert lib.assertMsg (
  platforms ? ${hardening.managementPlatform}
) "switch-0: unknown managementPlatform ${hardening.managementPlatform}";
assert lib.assertMsg (lib.elem hardening.dhcpSnooping.trustedPortSource trustedPortSources)
  "switch-0: dhcpSnooping.trustedPortSource must be one of ${lib.concatStringsSep "|" trustedPortSources}";
{
  firmwareVersion = "1.0.7.128";

  management = {
    address = "192.168.69.2";
    netmask = "255.255.255.0";
    gateway = null;
    dns = null;
    vlan = 1;
    username = "admin";
  };

  inherit ports;

  hardening = hardening // {
    managementPlatformValue = platforms.${hardening.managementPlatform};
  };
}
