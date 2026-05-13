{
  inputs,
  ...
}:
let
  inherit (inputs.self.lib) publicData;
in
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "l02";

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

  flake.modules.nixos.l02 =
    { pkgs, ... }:
    {
      imports =
        with inputs.self.modules.nixos;
        [
          system-laptop-base
          system-hibernation
          services-fprintd
          services-slurm-client
          services-tablet
          l02-hardware
        ]
        ++ [
          (inputs.self + /pkgs/state_autocommit.nix)
          (inputs.self + /pkgs/github_backup.nix)
          (inputs.self + /pkgs/ntfy-listener.nix)
        ];

      networking.hostName = "l02";

      environment.sessionVariables.HYPRLAND_IS_L02 = "1";

      environment.etc."libinput/local-overrides.quirks".text = ''
        [ELAN2513 Metapen MCP2 Stylus Pressure]
        MatchName=ELAN2513:00 04F3:4302 Stylus
        MatchBus=i2c
        AttrPressureRange=40:10
      '';

      system = {
        disko = {
          device = "/dev/disk/by-id/nvme-PC_SN8000S_SDEPNRG-2T00-1006_25290K800525";
          swapSize = "32G";
        };
        impermanence = {
          persistentDirs = [
            "/var/lib/libvirt"
            "/var/log"
            "/var/lib/bluetooth"
            "/var/lib/fprint"
          ];
          extraPersistentUserDirs = [
            ".config/pulse"
            ".local/state/pipewire"
            ".local/state/wireplumber"
            ".config/mozilla"
          ];
        };
        user = {
          username = "emre";
          uid = 1000;
          hashedPassword = publicData.passwords.l02;
          useHomeManager = true;
          extraGroups = [ "kvm" ];
          homeManagerImports = [ inputs.self.modules.homeManager.desktop ];
        };
      };

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
        hasTailscaleAuthority = true;
      };

      services = {
        logind.settings.Login = {
          HandleLidSwitch = "suspend-then-hibernate";
          HandleLidSwitchExternalPower = "suspend-then-hibernate";
          HandleLidSwitchDocked = "ignore";
        };

        tailscale.loginServerHost = "sshr.polarbearvuzi.com";

        slurm-client = {
          enable = true;
          masterHostname = "vm-oracle-aarch64";
        };
      };

      boot = {
        kernelParams = [ "video.brightness_switch_enabled=0" ];
        binfmt.emulatedSystems = [ "aarch64-linux" ];
        kernel.sysctl = {
          "net.ipv4.ip_forward" = 1;
          "fs.file-max" = "20480000";
          "fs.inotify.max_user_watches" = "20480000";
          "fs.inotify.max_user_instances" = "20480000";
          "fs.inotify.max_queued_events" = "20480000";
          "kernel.perf_event_paranoid" = 1;
        };
        kernelPackages = pkgs.linuxPackages_latest;
        supportedFilesystems = [
          "ntfs"
          "xfs"
        ];
      };
    };
}
