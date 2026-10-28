{ config, lib, ... }:
let
  inherit (config.networking) firewall;
  rulesOutsideTailnet = [
    firewall
  ]
  ++ lib.attrValues (removeAttrs firewall.interfaces [ config.services.tailscale.interfaceName ]);
  openedOutsideTailnet =
    protocol:
    lib.sort lib.lessThan (
      lib.unique (
        lib.concatMap (
          rules:
          rules."allowed${protocol}Ports"
          ++ lib.concatMap (range: lib.range range.from range.to) rules."allowed${protocol}PortRanges"
        ) rulesOutsideTailnet
      )
    );
  ociSecurityList = {
    TCP = [
      22
      80
      443
    ];
    UDP = [
      3478
      41641
    ];
  };
in
{
  assertions = map (protocol: {
    assertion = openedOutsideTailnet protocol == ociSecurityList.${protocol};
    message = "vps-oracle-0 opens ${protocol} ports [${toString (openedOutsideTailnet protocol)}] outside the tailnet, but the OCI security list allows [${
      toString ociSecurityList.${protocol}
    }]. Change both together.";
  }) (lib.attrNames ociSecurityList);

  time.timeZone = "Europe/Zurich";

  services = {
    qemuGuest.enable = true;
    udev.extraRules = ''
      KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_VENDOR}=="ORACLE", ENV{ID_MODEL}=="BlockVolume", ENV{ID_PATH}=="*:1", SYMLINK+="oracleoci/oraclevda"
      KERNEL=="sd*", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_VENDOR}=="ORACLE", ENV{ID_MODEL}=="BlockVolume", ENV{ID_PATH}=="*:1", SYMLINK+="oracleoci/oraclevda%n"
    '';
  };

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "virtio_pci"
      "virtio_scsi"
      "usbhid"
    ];
    initrd.kernelModules = [ "dm-snapshot" ];
    binfmt.emulatedSystems = [
      "x86_64-linux"
      "riscv64-linux"
    ];
  };

  networking.useDHCP = lib.mkDefault true;

}
