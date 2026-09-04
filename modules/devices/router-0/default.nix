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
  router-ui = inputs.nur.packages.${system}.router-ui;
  firmware = pkgs.callPackage ./nix/firmware.nix { inherit openwrtSource router-ui; };

  authorizedKeys = pkgs.writeText "router-0-authorized-keys" (
    pkgs.lib.concatStringsSep "\n" self.lib.kexecRootKeys + "\n"
  );

  mkConfigOverlay =
    args:
    import ./nix/config-overlay.nix (
      {
        inherit pkgs router-ui;
        inherit hostname;
        tailscaleLoginServer = facts.labels.tailscale_login_server;
      }
      // args
    );

  config-overlay = mkConfigOverlay { bootstrap = false; };
  config-overlay-bootstrap = mkConfigOverlay { bootstrap = true; };

  firmware-flash = pkgs.writeShellApplication {
    name = "router-0-firmware-flash";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssh
    ];
    text = ''
      export R0_DEFAULT_IP=${facts.labels.lan_ip}
      export R0_EXPECTED_REVISION=${openwrtSource.upstreamVersion}
    ''
    + builtins.readFile ./nix/flash.bash;
  };

  config = pkgs.writeShellApplication {
    name = "router-0-config";
    runtimeInputs = [
      pkgs.age
      pkgs.coreutils
      pkgs.gnutar
      pkgs.gzip
      pkgs.openssh
      pkgs.python3
      pkgs.remarshal
      pkgs.sops
    ];
    text = ''
      export R0_DEFAULT_IP=${facts.labels.lan_ip}
      export R0_OVERLAY=${config-overlay}
      export R0_OVERLAY_BOOTSTRAP=${config-overlay-bootstrap}
      export R0_WIFI_TO_UCI=${./nix/wifi-to-uci.py}
      export R0_AUTHORIZED_KEYS=${authorizedKeys}
    ''
    + builtins.readFile ./nix/config.bash;
  };
in
{
  packages = {
    inherit
      firmware
      router-ui
      config-overlay
      config-overlay-bootstrap
      ;
    openwrt-source = openwrtSource;
  };

  apps = {
    firmware-flash = {
      type = "app";
      program = "${firmware-flash}/bin/router-0-firmware-flash";
      meta.description = "Verify and flash a sysupgrade image onto router-0";
    };
    config = {
      type = "app";
      program = "${config}/bin/router-0-config";
      meta.description = "Converge router-0 onto the configuration in this repository";
    };
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
