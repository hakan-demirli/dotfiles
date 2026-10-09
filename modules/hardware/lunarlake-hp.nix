{
  lib,
  pkgs,
  ...
}:
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
    url = "https://github.com/user-attachments/files/33251307/acpi.zip";
    hash = "sha256-4kCECL/RLOmejuZcDZ3aFEaxuGMKJFYC11PR7JRmFK4=";
  };
  acpiOverride = pkgs.runCommand "acpi-override" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    mkdir -p kernel/firmware/acpi
    unzip -p ${acpiOverrideZip} dsdt.aml > kernel/firmware/acpi/dsdt.aml
    unzip -p ${acpiOverrideZip} ssdt-laptoppc.aml > kernel/firmware/acpi/ssdt-laptoppc.aml
    find kernel | ${pkgs.cpio}/bin/cpio -H newc --create > $out
  '';

  hpPower = pkgs.writeShellScriptBin "hp-power" ''
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gawk
        pkgs.kmod
        pkgs.msr-tools
        pkgs.util-linux
      ]
    }
    ${builtins.readFile ./hp-power.sh}
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

  environment.systemPackages = [
    hpPower
    pkgs.msr-tools
  ];

  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands =
        map
          (mode: {
            command = "${hpPower}/bin/hp-power ${mode}";
            options = [
              "NOPASSWD"
              "NOSETENV"
            ];
          })
          [
            "turbo"
            "balanced"
            "silent"
          ];
    }
  ];

  systemd.tmpfiles.rules = [ "d /run/hp-power 0755 root root -" ];

  hardware = {
    sensor.iio.enable = true;
    firmware = [ ishFirmware ];
  };
}
