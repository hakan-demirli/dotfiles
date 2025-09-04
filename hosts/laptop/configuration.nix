{
  pkgs,
  ...
}@specialArgsFromFlake:

let
  defaultArgs = rec {
    hostName = "laptop";
    diskDevice = "/dev/nvme1n1";
    swapSize = "32G";
    timeZone = "Europe/Istanbul";
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = { };
    username = "emre";
    uid = 1000;
    emulatedSystems = [ ];

    hashedPassword = throw "You must specify a hashedPassword";
    authorizedKeys = [ ];
    rootSshKeys = [ ];
    allowPasswordAuth = false;

    userExtraGroups = [ "kvm" ];
    persistentDirs = [
      "/var/lib/libvirt"
      "/var/lib/docker"

      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      "/var/lib/bluetooth"

      "/root/.cache/nix" # persist nix eval cache
    ];

    useHomeManager = true;
    homeManagerImports = [
      ../../users/${username}/home.nix
    ];
    homeManagerArgs = {
      gdriveDir = "/home/${username}/Desktop/gdrive";
      dotfilesDir = "/home/${username}/Desktop/dotfiles";
    };

    extraImports = [ ];
    extraGroups = [ ];
    extraSubstituters = [ ];
    extraTrustedPublicKeys = [ ];

    allowUnfree = true;
    cudaSupport = false;
    rocmSupport = false;

    maxJobs = 16;
    maxSubstitutionJobs = 256;
    nixCores = 16;

    grubDevice = "nodev";
    useOSProber = true;
    efiInstallAsRemovable = false;
    canTouchEfiVariables = true;
  };

  finalArgs = defaultArgs // specialArgsFromFlake;
in
{

  _module.args = builtins.removeAttrs finalArgs [
    # Prevent Recursion
    "pkgs"
    "lib"
    "inputs"
    "system"
    # "config"
    # "options"
    # "_module"
  ];

  imports = [
    ../common/system/base.nix
    ../common/system/locale.nix

    ../common/hardware/disko-btrfs-lvm.nix
    ../common/system/impermanence-btrfs.nix
    ../common/system/v4l2loopback.nix
    ../common/users/user-base.nix
    ../common/nix/settings.nix
    ../common/system/bootloader-grub-efi.nix
    # ../common/services/ssh.nix # no ssh on laptop
    ../common/services/sddm-hyprland.nix
    ../common/services/base-desktop.nix
    ../common/services/warp.nix
    ../common/services/tailscale.nix

    ./hardware-configuration.nix
    ./nvidia.nix
    ./battery.nix

    ./virtualisation.nix
    ./ydotool.nix
    ../../pkgs/symlink_secrets.nix
    ../../pkgs/state_autocommit.nix
  ]
  ++ finalArgs.extraImports;

  environment.persistence."/persist" = {
    users.${finalArgs.username} = {
      directories = [
        ".config/pulse"
        ".local/state/pipewire"
        ".local/state/wireplumber"
        ".cache"
        ".mozilla"
        ".local/share"
        "Desktop"
        "Documents"
        "Downloads"
        "Videos"
      ];
    };
  };

  networking = {
    hostName = finalArgs.hostName;
    networkmanager.enable = true;
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1; # required to share your internet
    # "net.ipv6.conf.all.forwarding" = 1;

    # fix too many files open
    "fs.file-max" = "20480000";
    "fs.inotify.max_user_watches" = "20480000";
    "fs.inotify.max_user_instances" = "20480000";
    "fs.inotify.max_queued_events" = "20480000";
  };

  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.network.wait-online.enable = false;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [

  ];

  boot.supportedFilesystems = [ "ntfs" ];
  fileSystems."/mnt/second" = {
    device = "/dev/disk/by-uuid/120CC7A90CC785E7";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=${toString finalArgs.uid}"
    ];
  };

  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.corefonts
  ];

  environment.systemPackages = with pkgs; [
    home-manager
    git
    (
      if finalArgs.rocmSupport then
        btop-rocm
      else if finalArgs.cudaSupport then
        btop-cuda
      else
        btop
    )
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

  programs.gnome-disks.enable = true;

  hardware.keyboard.qmk.enable = true;

  boot.binfmt.emulatedSystems = finalArgs.emulatedSystems;

  system.stateVersion = "25.05";
}
