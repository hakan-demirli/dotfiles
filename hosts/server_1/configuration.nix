{
  inputs,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware/hardware-configuration.nix
    ./system/graphics.nix
    ./system/bootloader.nix
    ../../pkgs/reverse_ssh.nix
    ../../pkgs/symlink_gitconfig.nix
    (import ./hardware/disko.nix { device = "/dev/nvme0n1"; })
  ];

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
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      "/var/lib/cloudflare-warp"
      # allow linger
      "/var/lib/systemd/timesync/clock"
      "/var/lib/systemd/linger"
      "/var/lib/systemd/timers"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /persist/home/ 0777 root root -" # create /persist/home owned by root
    "d /persist/home/emre 0700 emre users -" # /persist/home/emre owned by that user
  ];
  ###################################################
  #                     Network                     #
  ###################################################
  networking.hostName = "server_1";
  networking.networkmanager.enable = true;

  ###################################################
  #                     Nix                         #
  ###################################################
  documentation.nixos.enable = false; # .desktop
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
        "https://ai.cachix.org"
        "https://nix-community.cachix.org"
        "https://cuda-maintainers.cachix.org"
        "https://numtide.cachix.org"
      ];
      trusted-public-keys = [
        "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      ];

      max-jobs = 16;
      cores = 16;
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
      # use-xdg-base-directories = true; # https://github.com/nix-community/home-manager/issues/5805

      # Prevent garbage collection from altering nix-shells managed by nix-direnv
      # https://github.com/nix-community/nix-direnv#installation
      keep-outputs = true;
      keep-derivations = true;
      # perf
      max-substitution-jobs = 256;
    };
  };

  ###################################################
  #                    Security                     #
  ###################################################

  security.polkit.enable = true;
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
  # https://github.com/NixOS/nixpkgs/issues/189851
  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/current-system/sw/bin"
  '';

  hardware = {
    keyboard.qmk.enable = true;
    uinput.enable = true; # xremap dep
  };

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
    linger = true;
    # mkpasswd -m sha-512 "my_super_secret_pass"
    hashedPassword = "$6$hjsD4y4Iy/9ql6dC$WYxNpnvlx9r6TbGwWcXMqzzsyzh6IvftawYlyvwB4/Zr21UNO5eyj87WB2JqcH.EoO3rmP10P5X/d0b6tNcSh/";
    uid = 1000;
    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "uinput"
      "input"
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
        (import ../../users/emre-server/home.nix {
          inherit pkgs inputs config;
          gdriveDir = /home/emre/Desktop/gdrive;
          dotfilesDir = /home/emre/Desktop/dotfiles;
        })
      ];
    };
  };
  security.pam.services.swaylock = { }; # without this swaylock is broken

  ###################################################
  #                    Packages                     #
  ###################################################
  fonts = {
    packages = [
      pkgs.nerd-fonts.jetbrains-mono
    ];
  };

  environment = {
    localBinInPath = true;

    sessionVariables = {
      # If your cursor becomes invisible
      WLR_NO_HARDWARE_CURSORS = "1";
      # Hint electron apps to use wayland
      NIXOS_OZONE_WL = "1";
    };

    systemPackages = with pkgs; [
      home-manager
      git

      btop
      fzf
      kitty
      foot # BACKUP TERMINAL
      xterm # BACKUP TERMINAL

      tofi

      git-crypt
      wget
      neovim # default editor

      (pkgs.callPackage ../../pkgs/sddm-astronaut.nix {
        # theme = "pixel_sakura";
      })
    ];
  };

  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
    };
    gnome-disks.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  services.openssh.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBZuf6oNuOd8+zyXt8Idh0Wx3irSx6IwcgxrEMfBgevV ehdemirli@proton.me"
  ];

  users.users.emre.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBZuf6oNuOd8+zyXt8Idh0Wx3irSx6IwcgxrEMfBgevV ehdemirli@proton.me"
  ];

  services.cloudflare-warp = {
    enable = true;
    package = pkgs.cloudflare-warp;
  };

  ###################################################
  #                   Keymapping                    #
  ###################################################
  services = {
    dbus.enable = true;
    # services.asusd.enable = true;
    # services.asusd.enableUserService = true;
    displayManager.sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        kdePackages.qtmultimedia
        kdePackages.qtsvg
        kdePackages.qtvirtualkeyboard
      ];
      # https://github.com/NixOS/nixpkgs/issues/355912#issuecomment-2480923686
      settings = {
        General = {
          DefaultSession = "hyprland.desktop";
        };
      };
    };
    xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];
    };

    gnome.gnome-keyring.enable = true; # NOTE: Required for mysql-workbench

    # open-webui = {
    #   enable = true;
    #   host = "127.0.0.1";
    #   port = 8081;
    #   environment = {
    #     # OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
    #     # Disable authentication
    #     #
    #     SCARF_NO_ANALYTICS = "True";
    #     DO_NOT_TRACK = "True";
    #     ANONYMIZED_TELEMETRY = "False";
    #     WEBUI_AUTH = "False";
    #   };
    # };
  };

  ###################################################
  #                     NixOS                       #
  ###################################################
  system.stateVersion = "23.11"; # Did you read the comment?
}
