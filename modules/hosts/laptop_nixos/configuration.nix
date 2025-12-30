{
  inputs,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
in
{
  flake.modules.nixos.laptop = { config, pkgs, lib, ... }: {
    imports = with inputs.self.modules.nixos; [
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
      # Laptop-specific modules
      laptop-hardware
      system-nvidia
      system-battery
      system-gnupg
      system-virtualisation
    ] ++ [
      (inputs.self + /pkgs/state_autocommit.nix)
    ];

    # Host specific config
    networking.hostName = "laptop";
    time.timeZone = "Europe/Zurich";

    # Options from modules
    system.disko = {
      device = "/dev/nvme1n1";
      swapSize = "32G";
    };

    system.impermanence = {
      username = "emre";
      uid = 1000;
      persistentDirs = [
        "/var/lib/libvirt"
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/NetworkManager/system-connections"
        "/var/lib/bluetooth"
        "/root/.cache/nix"
      ];
    };

    system.user = {
      username = "emre";
      uid = 1000;
      hashedPassword = publicData.passwords.laptop;
      useHomeManager = true;
      extraGroups = [ "kvm" ];
      homeManagerImports = [ inputs.self.modules.homeManager.desktop ];
    };

    nix.custom = {
      allowUnfree = true;
      cudaSupport = false;
      rocmSupport = false;
      username = "emre";
    };

    sops.defaultSopsFile = inputs.self + /secrets/secrets.yaml;
    sops.age.keyFile = "/var/lib/sops-nix/key.txt";
    sops.secrets.tailscale-key = {};

    services.tailscale.reverseSshRemoteHost = "sshr.polarbearvuzi.com";

    # Extra config from legacy configuration.nix
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "fs.file-max" = "20480000";
      "fs.inotify.max_user_watches" = "20480000";
      "fs.inotify.max_user_instances" = "20480000";
      "fs.inotify.max_queued_events" = "20480000";
    };
    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.supportedFilesystems = [ "ntfs" ];

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
      home-manager
      git
      btop
      fzf
      kitty
      foot
      xterm
      tofi
      git-crypt
      wget
      neovim
      file
    ];

    documentation = {
      enable = true;
      nixos.enable = true;
    };

    hardware.keyboard.qmk.enable = true;
    system.stateVersion = "25.05";
  };
}
