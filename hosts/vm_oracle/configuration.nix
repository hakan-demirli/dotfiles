{
  inputs,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware/hardware-configuration.nix
    (import ./hardware/disko.nix { device = "/dev/sda"; })
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true; # Assuming EFI boot
  boot.loader.grub.device = "/dev/sda";

  ###################################################
  #                    FileSystem                   #
  ###################################################
  boot.initrd.postDeviceCommands = pkgs.lib.mkAfter ''
    mkdir /btrfs_tmp
    mount /dev/root_vg/root /btrfs_tmp
    if [[ -e /btrfs_tmp/root ]]; then
        mkdir -p /btrfs_tmp/old_roots
        timestamp=$(date --date="@$(stat -c %Y /btrfs_tmp/root)" "+%Y-%m-%-d_%H:%M:%S")
        mv /btrfs_tmp/root "/btrfs_tmp/old_roots/$timestamp"
    fi

    delete_subvolume_recursively() {
        IFS=$'\n'
        for i in $(btrfs subvolume list -o "$1" | cut -f 9- -d ' '); do
            delete_subvolume_recursively "/btrfs_tmp/$i"
        done
        btrfs subvolume delete "$1"
    }

    for i in $(find /btrfs_tmp/old_roots/ -maxdepth 1 -mtime +30); do
        delete_subvolume_recursively "$i"
    done

    btrfs subvolume create /btrfs_tmp/root
    umount /btrfs_tmp
  '';

  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist/system" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /persist/home/ 0777 root root -" # create /persist/home owned by root
    "d /persist/home/emre 0700 emre users -" # /persist/home/emre owned by that user
  ];

  ###################################################
  #                     Network                     #
  ###################################################
  networking.hostName = "vm";
  networking.networkmanager.enable = true;

  ###################################################
  #                     Nix                         #
  ###################################################
  documentation.nixos.enable = false;
  nixpkgs.config = {
    allowUnfree = true;
    rocmSupport = false;
    cudaSupport = false;
  };
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    settings = {
      substituters = [
        "https://nix-community.cachix.org"
        "https://numtide.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      ];

      max-jobs = 3;
      cores = 1;
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;

      keep-outputs = true;
      keep-derivations = true;
      max-substitution-jobs = 256;
    };
  };

  ###################################################
  #                    Security                     #
  ###################################################

  # https://github.com/NixOS/nixpkgs/issues/189851
  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/current-system/sw/bin"
  '';

  ###################################################
  #                    Location                     #
  ###################################################
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  ###################################################
  #                     Users                       #
  ###################################################

  # ---------------emre--------------
  users.users.emre = {
    isNormalUser = true;
    hashedPassword = "$6$hjsD4y4Iy/9ql6dC$WYxNpnvlx9r6TbGwWcXMqzzsyzh6IvftawYlyvwB4/Zr21UNO5eyj87WB2JqcH.EoO3rmP10P5X/d0b6tNcSh/";
    uid = 1000;
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
    ];
  };
  programs.fuse.userAllowOther = true;

  home-manager.extraSpecialArgs = {
    inherit inputs;
    inherit pkgs;
  };

  home-manager = {
    backupFileExtension = "backup";
    users.emre = {
      imports = [
        inputs.impermanence.nixosModules.home-manager.impermanence
        (import ../../users/emre-server-headless/home.nix {
          inherit pkgs inputs config;
          gdriveDir = /home/emre/Desktop/gdrive;
          dotfilesDir = /home/emre/Desktop/dotfiles;
        })
      ];
    };
  };

  ###################################################
  #                    Packages                     #
  ###################################################
  fonts = {
    packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  };

  environment = {
    localBinInPath = true;

    systemPackages = with pkgs; [
      home-manager
      git

      btop
      fzf

      git-crypt
      wget
      neovim
    ];
  };

  programs = {
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  ###################################################
  #                   Services                      #
  ###################################################
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBZuf6oNuOd8+zyXt8Idh0Wx3irSx6IwcgxrEMfBgevV ehdemirli@proton.me"
  ];

  users.users.emre.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBZuf6oNuOd8+zyXt8Idh0Wx3irSx6IwcgxrEMfBgevV ehdemirli@proton.me"
  ];

  services.dbus.enable = true;

  systemd.defaultUnit = "multi-user.target";

  system.stateVersion = "23.11";
}
