{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware/hardware-configuration.nix
    ./system/graphics.nix
    (import ./hardware/disko.nix { device = "/dev/vda"; })
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "/dev/vda";

  ###################################################
  #                    FileSystem                   #
  ###################################################
  boot.initrd.postDeviceCommands = lib.mkAfter ''
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
      "/var/lib/bluetooth"
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
  #                    Security                     #
  ###################################################

  security.polkit.enable = true;

  ###################################################
  #                    Location                     #
  ###################################################
  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
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
    # mkpasswd -m sha-512 "my_super_secret_pass"
    hashedPassword = "$6$dxLcMi321Rg6B7Nu$tRRLCU/7AEFKg7HW56XIKkbtowfyX4uSOq0M8.pKRZIgg6FrdF9o19yAf1mEov.C.SnhSlXG48rmVbVFqtbEn1";
    uid = 1000;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
  programs.fuse.userAllowOther = true;
  home-manager.extraSpecialArgs = {
    inherit inputs;
    inherit pkgs;
  };
  home-manager.users.emre = {
    imports = [
      inputs.impermanence.nixosModules.home-manager.impermanence
      ../../users/emre/home.nix
    ];
  };

  ###################################################
  #                    Packages                     #
  ###################################################
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    wl-clipboard
    nix-index
    kitty # required for the default Hyprland config
  ];

  programs.hyprland.enable = true; # enable Hyprland

  ###################################################
  #                   Keymapping                    #
  ###################################################
  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };

  ###################################################
  #                     NixOS                       #
  ###################################################

  nix.settings = {
    substituters = [ ];
    trusted-public-keys = [ ];
  };

  system.stateVersion = "23.11"; # Did you read the comment?

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
