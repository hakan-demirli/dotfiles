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
        ];

      networking.hostName = "laptop";
      networking.networkmanager.enable = true;
      time.timeZone = "Europe/Zurich";

      system = {
        disko = {
          device = "/dev/nvme1n1";
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

      services.tailscale.reverseSshRemoteHost = "sshr.polarbearvuzi.com";

      boot = {
        kernel.sysctl = {
          "net.ipv4.ip_forward" = 1;
          "fs.file-max" = "20480000";
          "fs.inotify.max_user_watches" = "20480000";
          "fs.inotify.max_user_instances" = "20480000";
          "fs.inotify.max_queued_events" = "20480000";
        };
        kernelPackages = pkgs.linuxPackages_latest;
        supportedFilesystems = [ "ntfs" ];
      };

      systemd.services.NetworkManager-wait-online.enable = false;
      systemd.network.wait-online.enable = false;

      fileSystems."/mnt/second" = {
        device = "/dev/disk/by-uuid/120CC7A90CC785E7";
        fsType = "ntfs-3g";
        options = [
          "rw"
          "uid=1000"
        ];
      };

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
