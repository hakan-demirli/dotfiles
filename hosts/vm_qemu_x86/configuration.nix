{
  pkgs,
  ...
}@specialArgsFromFlake:

let
  defaultArgs = rec {
    hostName = throw "You must specify a hostName";
    diskDevice = "/dev/vda";
    swapSize = "8G";
    timeZone = "Europe/Istanbul";
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = { };
    username = "emre";
    uid = 1000;
    emulatedSystems = [ ];

    hashedPassword = throw "You must specify a hashedPassword";
    hardwareConfiguration = throw "You must specify a hardwareConfiguration";
    authorizedKeys = [ ];
    rootSshKeys = [ ];
    allowPasswordAuth = true;

    slurmMaster = false;
    slurmNode = false;

    userExtraGroups = [ ];
    persistentDirs = [
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"

      "/root/.cache/nix" # persist nix eval cache
    ];

    useHomeManager = true;
    homeManagerImports = [
      ../../users/${username}-server-headless/home.nix
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

    maxJobs = 8;
    maxSubstitutionJobs = 8;
    nixCores = 8;

    grubDevice = "/dev/vda";
    canTouchEfiVariables = false;
    efiInstallAsRemovable = true;
    useOSProber = false;

    reverseSshSessionName = "reverse-tunnel";
    reverseSshRemoteBindAddress = "localhost";
    reverseSshRemotePort = 0;

    reverseSshLocalTargetPort = 22;
    reverseSshLocalTargetHost = "localhost";
    reverseSshPrivateKeyPath = throw "reverseSshPrivateKeyPath must be set for the client";
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
    ../common/services/docker.nix
    ../../pkgs/symlink_secrets.nix
  ]
  ++ finalArgs.extraImports;

  environment.persistence."/persist" = {
    users.${finalArgs.username} = {
      directories = [
        "Desktop"
        "Documents"
        "Downloads"
        "Videos"
        ".local/share/keyrings"
      ];
    };
  };

  networking.hostName = finalArgs.hostName;
  networking.networkmanager.enable = true;

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
    file
  ];

  boot.binfmt.emulatedSystems = finalArgs.emulatedSystems;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  system.stateVersion = "25.05";
}
