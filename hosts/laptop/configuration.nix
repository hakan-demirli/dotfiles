{
  pkgs,
  ...
}:

let
  commonArgs = rec {
    hostName = "laptop";
    diskDevice = "/dev/nvme1n1";
    swapSize = "32G";
    timeZone = "Europe/Istanbul";
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = { };
    username = "emre";
    uid = 1000;

    hashedPassword = throw "You must specify a hashedPassword";
    authorizedKeys = [ ];
    rootSshKeys = [ ];
    allowPasswordAuth = false;

    userExtraGroups = [ "kvm" ];
    persistentDirs = [
      "/var/lib/libvirt"
      "/var/lib/docker"
      "/var/lib/cloudflare-warp"
    ];

    useHomeManager = true;
    homeManagerImports = [
      ../../users/${username}-server-headless/home.nix
    ];
    homeManagerArgs = {
      gdriveDir = "/home/${username}/Desktop/gdrive";
      dotfilesDir = "/home/${username}/Desktop/dotfiles";
    };

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
    efiInstallAsRemovable = true;
    canTouchEfiVariables = false;

  };
in
{

  _module.args = commonArgs;

  imports = [

    ../common/system/base.nix
    ../common/system/locale.nix

    ../common/hardware/disko-btrfs-lvm.nix
    ../common/system/impermanence-btrfs.nix
    ../common/users/user-base.nix
    ../common/nix/settings.nix
    ../common/system/bootloader-grub-efi.nix
    # ../common/services/ssh.nix # no ssh on laptop
    ../common/services/sddm-hyprland.nix
    ../common/services/base-desktop.nix

    ./hardware-configuration.nix
    ./nvidia.nix
    ./battery.nix

    ./virtualisation.nix
    ./ydotool.nix

  ];

  networking.hostName = commonArgs.hostName;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [

  ];

  boot.supportedFilesystems = [ "ntfs" ];
  fileSystems."/mnt/second" = {
    device = "/dev/disk/by-uuid/120CC7A90CC785E7";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=${toString commonArgs.uid}"
    ];
  };

  fonts.packages = [ pkgs.corefonts ];

  environment.systemPackages = with pkgs; [
    home-manager
    git
    (btop.override { cudaSupport = false; })
    fzf
    kitty
    foot
    xterm
    tofi
    git-crypt
    wget
    neovim
  ];

  services.cloudflare-warp = {
    enable = true;
    package = pkgs.cloudflare-warp;
  };

  hardware.keyboard.qmk.enable = true;

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  system.stateVersion = "25.05";
}
