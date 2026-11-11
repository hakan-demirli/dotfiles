{ pkgs, ... }:
let
  ishFirmwareZip = pkgs.fetchurl {
    url = "https://github.com/user-attachments/files/27080938/ish.zip";
    hash = "sha256-2LblUbsI7ZePIwTupMhTb/foFFY9fo7Pqgwh3CHrU1Y=";
  };
  ishFirmware = pkgs.runCommand "ish-firmware" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    mkdir -p $out/lib/firmware/intel/ish
    unzip -p ${ishFirmwareZip} ishC_0207.bin > $out/lib/firmware/intel/ish/ish_lnlm_12128606.bin
  '';

  acpiOverrideZip = pkgs.fetchurl {
    url = "https://github.com/user-attachments/files/34321411/acpi.zip";
    hash = "sha256-yHOt0R5nkYr8kXkJbmB7t33B8S9ZnLDNF79f6wR2zXo=";
  };
  acpiOverride = pkgs.runCommand "acpi-override" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    mkdir -p kernel/firmware/acpi
    unzip -p ${acpiOverrideZip} dsdt.aml > kernel/firmware/acpi/dsdt.aml
    find kernel | ${pkgs.cpio}/bin/cpio -H newc --create > $out
  '';
in
{
  imports = [ ../system/power-profile.nix ];

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
    kernelParams = [ "acpi=copy_dsdt" ];
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

  hardware = {
    powerProfile = {
      backend = ./hp-omnibook-ultra-flip-14-power.sh;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gawk
        pkgs.kmod
        pkgs.msr-tools
      ];
    };
    sensor.iio.enable = true;
    firmware = [ ishFirmware ];
  };
}
