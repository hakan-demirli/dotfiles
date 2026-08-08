{
  pkgs,
  self,
  ...
}:
let
  facts = self.lib.inventory.hosts.kvm-desk-0;

  mkConfigOverlay =
    args:
    import ./nix/config-overlay.nix (
      {
        inherit pkgs;
        tailscaleLoginServer = facts.labels.tailscale_login_server;
        tailscaleTag = facts.labels.tailscale_tag;
        staticIp = facts.labels.lan_ip + "/24";
        inherit (facts) hostname;
      }
      // args
    );

  config-overlay-empty = mkConfigOverlay {
    authorizedKeys = null;
    tailscaleAuthKey = null;
    webAdminPasswordHash = null;
    customEdid = null;
    hdmiMode = null;
    hdmiWidth = null;
    hdmiHeight = null;
  };
in
{
  packages = {
    inherit config-overlay-empty;
  };

  lib = {
    inherit mkConfigOverlay;
  };

  meta = {
    kind = facts.hardware.os;
    hardware = facts.hardware.chassis;
    hardware_soc = facts.hardware.cpu_model;
    needsRelaxedSandbox = false;
    lan_ip = facts.labels.lan_ip;
    lan_cidr = facts.labels.lan_cidr;
    tailscale_tag = facts.labels.tailscale_tag;
    tailscale_login_server = facts.labels.tailscale_login_server;
    controls_host = facts.labels.controls_host;
    firmware_version = facts.labels.firmware_version;
    kvm_framework = facts.labels.kvm_framework;
  };
}
