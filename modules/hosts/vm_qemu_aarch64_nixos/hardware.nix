{
  flake.modules.nixos.vm_qemu_aarch64-hardware =
    { lib, ... }:
    {

      services.qemuGuest.enable = true;

      boot = {
        initrd.availableKernelModules = [
          "virtio_scsi"
          "sr_mod"
        ];
        initrd.kernelModules = [ "dm-snapshot" ];
        kernelModules = [ ];
        extraModulePackages = [ ];
      };

      networking.useDHCP = lib.mkDefault true;
      nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
    };
}
