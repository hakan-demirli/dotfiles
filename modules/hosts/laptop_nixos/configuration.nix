{
  inputs,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
in
{
  flake.modules.nixos.laptop =
    {
      pkgs,
      ...
    }:
    {
      imports =
        with inputs.self.modules.nixos;
        [
          system-base
          system-fonts
          system-locale
          system-impermanence
          system-polkit
          system-boot-grub
          system-disko-btrfs-lvm
          user-base
          nix-settings
          overlays
          services-hyprland
          services-tailscale
          services-docker
          services-warp
          services-earlyoom
          services-yubikey
          services-sops
          services-slurm-client
          # Laptop-specific modules
          laptop-hardware
          system-nvidia
          system-battery
          system-gnupg
          system-virtualisation
          system-sound
          system-bluetooth
          system-automount
          system-v4l2loopback
        ]
        ++ [
          (inputs.self + /pkgs/state_autocommit.nix)
          (inputs.self + /pkgs/github_backup.nix)
        ];

      networking.hostName = "laptop";
      networking.networkmanager.enable = true;
      time.timeZone = "Europe/Zurich";

      system = {
        disko = {
          device = "/dev/disk/by-id/nvme-KIOXIA-EXCERIA_SSD_X26FC0ZVF4M3";
          swapSize = "32G";
        };
        impermanence = {
          username = "emre";
          uid = 1000;
          persistentDirs = [
            "/var/lib/libvirt"
            "/var/log"
            "/var/lib/bluetooth"
          ];
          persistentUserDirs = [
            ".config/pulse"
            ".local/state/pipewire"
            ".local/state/wireplumber"
            ".cache"
            ".mozilla"
            ".local/share"
            ".antigravity"
            ".config/Antigravity"
            ".config/opencode"
            ".local/state/opencode"
            ".gemini"
            "Desktop"
            "Documents"
            "Downloads"
            "Videos"
          ];
        };
        user = {
          username = "emre";
          uid = 1000;
          hashedPassword = publicData.passwords.laptop;
          useHomeManager = true;
          extraGroups = [ "kvm" ];
          homeManagerImports = [ inputs.self.modules.homeManager.desktop ];
        };
      };

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
        username = "emre";
      };

      services = {
        tailscale.reverseSshRemoteHost = "sshr.polarbearvuzi.com";

        slurm-client = {
          enable = true;
          masterHostname = "vm-oracle-aarch64";
        };

        # prevent sleep. laptop gpu dies if it sleeps. Hardware/Firmware bug.
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

      systemd.services.NetworkManager-wait-online.enable = false;
      systemd.network.wait-online.enable = false;

      environment.systemPackages = with pkgs; [
        kitty
        foot
        xterm
        tofi
      ];

      documentation = {
        enable = true;
        nixos.enable = true;
      };

      hardware.keyboard.qmk.enable = true;
      system.stateVersion = "25.05";
    };
}
