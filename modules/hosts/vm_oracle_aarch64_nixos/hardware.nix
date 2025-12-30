{
  flake.modules.nixos.vm_oracle_aarch64-hardware =
    { lib, ... }:
    {

      services.qemuGuest.enable = true;

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "virtio_pci"
          "virtio_scsi"
          "usbhid"
        ];
        initrd.kernelModules = [ "dm-snapshot" ];
        kernelModules = [ ];
        extraModulePackages = [ ];
      };

      networking.useDHCP = lib.mkDefault true;
      nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
    };
}
