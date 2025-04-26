{
  pkgs,
  ...
}:

let
  commonArgs = rec {
    hostName = "vm_qemu_x86";
    diskDevice = "/dev/vda";
    swapSize = "8G";
    timeZone = "Europe/Istanbul";
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = { };
    username = "emre";
    uid = 1000;

    hashedPassword = throw "You must specify a hashedPassword";
    authorizedKeys = [ ];
    rootSshKeys = [ ];
    allowPasswordAuth = true;

    userExtraGroups = [ ];
    persistentDirs = [ ];

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

    maxJobs = 8;
    maxSubstitutionJobs = 8;
    nixCores = 8;

    grubDevice = "/dev/vda";
    canTouchEfiVariables = false;
    efiInstallAsRemovable = true;
    useOSProber = false;
  };
in
{
  _module.args = commonArgs;

  imports = [
    # Common Modules
    ../common/system/base.nix
    ../common/system/locale.nix
    # ../common/system/network.nix # NetworkManager enabled below
    ../common/hardware/disko-btrfs-lvm.nix
    ../common/system/impermanence-btrfs.nix
    ../common/users/user-base.nix
    ../common/nix/settings.nix
    ../common/system/bootloader-grub-efi.nix
    ../common/services/ssh.nix
    # No GUI services needed
  ];

  # == Host Specific Configuration ==

  networking.hostName = commonArgs.hostName;
  networking.networkmanager.enable = true; # Enable NetworkManager for VM networking

  # System target (headless server)
  systemd.defaultUnit = "multi-user.target";

  # Basic packages for a headless server
  environment.systemPackages = with pkgs; [
    home-manager
    git
    btop
    fzf
    git-crypt
    wget
    neovim
  ];

  system.stateVersion = "25.05";
}
