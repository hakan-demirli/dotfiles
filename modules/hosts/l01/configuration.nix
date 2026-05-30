{
  inputs,
  ...
}:
let
  inherit (inputs.self.lib) publicData;
in
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "x86_64-linux" "l01";

  flake.modules.nixos.l01-hardware =
    { lib, config, ... }:
    {
      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "nvme"
          "ahci"
          "usb_storage"
          "usbhid"
          "sd_mod"
        ];
        initrd.kernelModules = [ ];
        kernelModules = [ "kvm-amd" ];
        extraModulePackages = [ ];
      };

      fileSystems = {
        "/mnt/second" = {
          device = "/dev/disk/by-uuid/120CC7A90CC785E7";
          fsType = "ntfs-3g";
          options = [
            "rw"
            "uid=1000"
          ];
        };
      };

      networking.useDHCP = lib.mkDefault true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };

  flake.modules.nixos.l01 =
    {
      pkgs,
      ...
    }:
    {
      imports =
        with inputs.self.modules.nixos;
        [
          system-laptop-base
          system-hibernation
          services-slurm-client
          services-remotedesktop
          services-ssh
          l01-hardware
          system-nvidia
        ]
        ++ [
          (inputs.self + /pkgs/state_autocommit.nix)
          (inputs.self + /pkgs/github_backup.nix)
          (inputs.self + /pkgs/ntfy-listener.nix)
        ];

      networking.hostName = "l01";

      environment.sessionVariables.HYPRLAND_IS_L01 = "1";

      system = {
        disko = {
          device = "/dev/disk/by-id/nvme-KIOXIA-EXCERIA_SSD_X26FC0ZVF4M3";
          swapSize = "32G";
        };
        impermanence = {
          persistentDirs = [
            "/var/lib/libvirt"
            "/var/log"
            "/var/lib/bluetooth"
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
          hashedPassword = publicData.passwords.l01;
          authorizedKeys = [ publicData.ssh.id_ed25519_proton_pub ];
          useHomeManager = true;
          extraGroups = [ "kvm" ];
          homeManagerImports = [
            inputs.self.modules.homeManager.desktop
            (_: {
              xdg.configFile."sunshine/sunshine.conf".text = ''
                adapter_name = /dev/dri/renderD129
                audio_sink = sink-sunshine-stereo.monitor
              '';

              xdg.configFile."systemd/user/sunshine.service.d/override.conf".text = ''
                [Service]
                Environment=LIBVA_DRIVER_NAME=radeonsi
                Environment=XDG_RUNTIME_DIR=/run/user/1000
                Environment=PULSE_SERVER=unix:/run/user/1000/pulse/native
                Environment=PULSE_COOKIE=%h/.config/pulse/cookie
                Environment=WAYLAND_DISPLAY=wayland-1
                Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
              '';
            })
          ];
        };
      };

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
        hasNvidia = true;
        hasTailscaleAuthority = true;
      };

      services = {
        remotedesktop.enable = true;

        ssh.rootSshKeys = [ publicData.ssh.id_ed25519_proton_pub ];

        tailscale.loginServerHost = "sshr.polarbearvuzi.com";

        slurm-client = {
          enable = true;
          masterHostname = "vm-oracle-aarch64";
        };

        logind.settings.Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchExternalPower = "ignore";
          HandleLidSwitchDocked = "ignore";
        };
      };

      boot = {
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
        supportedFilesystems = [ "ntfs" ];
      };
    };
}
