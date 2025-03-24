{

  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [
    (import ./hardware/disko.nix { device = "/dev/nvme1n1"; })
    ./hardware/hardware-configuration.nix
    ./hardware/nvidia.nix
    ./system/battery.nix
    ./system/virtualisation.nix
    ./system/locale.nix
    ./system/bootloader.nix
    ./system/bluetooth.nix
    ./system/network.nix
    ./system/automount.nix
    ./system/sound.nix
    # ./system/printing.nix # fck printers
  ];

  # nix
  documentation.nixos.enable = false; # .desktop
  nixpkgs.config = {
    allowUnfree = true;
    rocmSupport = false;
    cudaSupport = false; # ok with cachix
    # cudaSupport = false; # takes hours to compile, dont touch
    allowUnfreePredicate =
      p:
      builtins.all (
        license:
        license.free
        || builtins.elem license.shortName [
          "CUDA EULA"
          "cuDNN EULA"
          "cuTENSOR EULA"
          "NVidia OptiX EULA"
        ]
      ) (if builtins.isList p.meta.license then p.meta.license else [ p.meta.license ]);
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

  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
    };
    gnome-disks.enable = true;
  };

  fonts = {
    packages = [
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.corefonts # microsoft fonts for pptx/word/excell
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

      (btop.override { cudaSupport = false; })
      fzf
      kitty
      foot # BACKUP TERMINAL
      xterm # BACKUP TERMINAL

      tofi

      git-crypt
      wget
      neovim # default editor

      (pkgs.callPackage ../../pkgs/derivations/sddm-astronaut.nix {
        # theme = "pixel_sakura";
      })
    ];
  };
  # services
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

  # test: `cpupower frequency-info`
  boot = {
    kernel.sysctl."fs.file-max" = 9223372036854775807; # https://github.com/NixOS/nix/issues/8684
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      # "amd_iommu=off"
      # "idle=nomwait"
      # "amdgpu.gpu_recovery=1"

      "amd_pstate=guided"

      # ''acpi_osi="Windows 2020"''

      "quiet"
      "mitigations=off"
    ];
    supportedFilesystems = [ "ntfs" ];
    tmp.cleanOnBoot = true;
  };

  # systemctl status --user polkit-gnome-authentication-agent-1
  # systemctl restart --user polkit-gnome-authentication-agent-1
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

  services.cloudflare-warp = {
    enable = true;
    package = pkgs.cloudflare-warp;
  };
  # # https://github.com/NixOS/nixpkgs/issues/97795#issuecomment-693354398
  # systemd.services.display-manager.wants = [
  #   "systemd-user-sessions.service"
  #   "multi-user.target"
  #   "network-online.target"
  # ];
  # systemd.services.display-manager.after = [
  #   "systemd-user-sessions.service"
  #   "multi-user.target"
  #   "network-online.target"
  # ];

  # https://github.com/NixOS/nixpkgs/issues/189851
  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/current-system/sw/bin"
  '';

  hardware = {
    keyboard.qmk.enable = true;
    uinput.enable = true; # xremap dep
  };

  # User account
  users.users.emre = {
    isNormalUser = true;
    # mkpasswd -m sha-512 "my_super_secret_pass"
    hashedPassword = "$6$dxLcMi321Rg6B7Nu$tRRLCU/7AEFKg7HW56XIKkbtowfyX4uSOq0M8.pKRZIgg6FrdF9o19yAf1mEov.C.SnhSlXG48rmVbVFqtbEn1";
    uid = 1000;
    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "uinput"
      "input"
      "libvirtd"
      "libvirt"
      "kvm"
      "docker"
    ];
  };

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
      "/var/lib/libvirt"
      "/etc/NetworkManager/system-connections"
      "/var/lib/docker"
    ];
  };
  systemd.tmpfiles.rules = [
    "d /persist/home/ 0777 root root -" # create /persist/home owned by root
    "d /persist/home/emre 0700 emre users -" # /persist/home/emre owned by that user
  ];

  programs.fuse.userAllowOther = true;
  home-manager = {
    extraSpecialArgs = {
      inherit inputs;
      inherit pkgs;
    };
    backupFileExtension = "backup";
    users.emre = {
      imports = [
        inputs.impermanence.nixosModules.home-manager.impermanence

        (import ../../users/emre/home.nix {
          inherit pkgs inputs config;
          gdriveDir = /home/emre/Desktop/gdrive;
          dotfilesDir = /home/emre/Desktop/dotfiles;
        })

      ];
    };
  };

  security.pam.services.swaylock = { }; # without this swaylock is broken

  # List packages installed in system profile. To search, run:
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  # services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
