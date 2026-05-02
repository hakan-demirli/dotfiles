{
  flake.modules.nixos.l02-hardware =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      ishFirmwareZip = pkgs.fetchurl {
        url = "https://github.com/user-attachments/files/27080938/ish.zip";
        hash = "sha256-2LblUbsI7ZePIwTupMhTb/foFFY9fo7Pqgwh3CHrU1Y=";
      };

      acpiOverrideZip = pkgs.fetchurl {
        url = "https://github.com/user-attachments/files/27299048/acpi.zip";
        hash = "sha256-ofDcvP7pwLH2AfJzueQt0wEFB3cN2AHf/RtYoV41iN0=";
      };
      acpiOverride = pkgs.runCommand "acpi-override" { nativeBuildInputs = [ pkgs.unzip ]; } ''
        mkdir -p kernel/firmware/acpi
        unzip -p ${acpiOverrideZip} dsdt.aml > kernel/firmware/acpi/dsdt.aml
        unzip -p ${acpiOverrideZip} ssdt-laptoppc.aml > kernel/firmware/acpi/ssdt-laptoppc.aml
        find kernel | ${pkgs.cpio}/bin/cpio -H newc --create > $out
      '';
    in
    {
      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "thunderbolt"
          "nvme"
          "usb_storage"
          "sd_mod"
        ];
        initrd.prepend = [ "${acpiOverride}" ];
        initrd.kernelModules = [ ];
        kernelModules = [
          "kvm-intel"
          "intel_ishtp_hid"
        ];
        extraModulePackages = [ ];
      };

      networking.useDHCP = lib.mkDefault true;

      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      hardware.sensor.iio.enable = true;

      nixpkgs.overlays = [
        (_final: prev: {
          linux-firmware = prev.linux-firmware.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.unzip ];
            postInstall = (old.postInstall or "") + ''
              ${pkgs.unzip}/bin/unzip -p ${ishFirmwareZip} ishC_0207.bin \
                > $out/lib/firmware/intel/ish/ish_lnlm_12128606.bin
              chmod 0444 $out/lib/firmware/intel/ish/ish_lnlm_12128606.bin
            '';
          });
        })
      ];
    };
}
