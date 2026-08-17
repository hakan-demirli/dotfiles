{
  pkgs,
  system,
  inputs,
  self,
  ...
}:
let
  facts = self.lib.inventory.hosts.router-0;
  hostname =
    if facts.hostname == null then
      throw "router-0: inventory hostname must be set before generating firmware"
    else
      facts.hostname;

  openwrtSource = pkgs.callPackage ./nix/openwrt-source.nix { };
  r01-ui = inputs.nur.packages.${system}.r01-ui;
  firmware = pkgs.callPackage ./nix/firmware.nix { inherit openwrtSource r01-ui; };

  mkConfigOverlay =
    args:
    import ./nix/config-overlay.nix (
      {
        inherit pkgs r01-ui;
        inherit hostname;
        tailscaleLoginServer = facts.labels.tailscale_login_server;
      }
      // args
    );

  config-overlay-empty = mkConfigOverlay {
    wifiToml = null;
    eapPassword = null;
    lanWifiPassword = null;
    authorizedKeys = null;
    tailscaleAuthKey = null;
    bootstrap = true;
  };
in
{
  packages = {
    inherit firmware r01-ui config-overlay-empty;
    openwrt-source = openwrtSource;
  };

  lib = {
    inherit mkConfigOverlay;
  };

  meta = {
    kind = facts.hardware.os;
    hardware = facts.hardware.chassis;
    hardware_soc = facts.hardware.cpu_model;
    inherit hostname;
    needsRelaxedSandbox = false;
    lan_ip = facts.labels.lan_ip;
    lan_cidr = facts.labels.lan_cidr;
    tailscale_tag = facts.labels.tailscale_tag;
    tailscale_login_server = facts.labels.tailscale_login_server;
  };
}
