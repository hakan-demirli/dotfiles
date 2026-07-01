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
    url = "https://github.com/user-attachments/files/27517608/acpi.zip";
    hash = "sha256-ECyBUsssI5jVCYW8RJ0WUmzRFReha0O6j7QxWb/6pKw=";
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
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "usb_storage"
        "sd_mod"
      ];
      prepend = [ "${acpiOverride}" ];
      kernelModules = [ ];
    };
    kernelModules = [
      "kvm-intel"
      "intel_ishtp_hid"
      "ec_sys"
      "msr"
    ];
    extraModprobeConfig = ''
      options ec_sys write_support=1
    '';
  };

  environment.systemPackages = [ pkgs.msr-tools ];

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
}
