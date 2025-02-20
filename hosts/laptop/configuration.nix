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
    kernel.sysctl."fs.file-max" = 100000; # https://github.com/NixOS/nix/issues/8684
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

  services.cloudflare-warp = {
    enable = true;
    package = pkgs.cloudflare-warp;
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
      "/etc/NetworkManager/system-connections"
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
