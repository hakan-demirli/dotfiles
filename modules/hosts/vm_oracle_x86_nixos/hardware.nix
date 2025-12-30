{
  flake.modules.nixos.vm_oracle_x86-hardware =
    { lib, ... }:
    {

      services.qemuGuest.enable = true;

      boot = {
        initrd.availableKernelModules = [
          "ahci"
          "xhci_pci"
          "virtio_pci"
          "virtio_blk"
          "sr_mod"
        ];
        initrd.kernelModules = [ "dm-snapshot" ];
        kernelModules = [ "kvm-amd" ];
        extraModulePackages = [ ];
      };

      networking.useDHCP = lib.mkDefault true;
      networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
