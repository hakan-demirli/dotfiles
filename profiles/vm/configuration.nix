{
  pkgs,
  userSettings,
  systemSettings,
  ...
}:
{
  imports = [
    ../../system/hardware/vm/hardware-configuration.nix
    # ../../system/hardware/virtualisation.nix
    ../../system/hardware/locale.nix
    ../../system/hardware/bootloader.nix
    ../../system/hardware/network.nix
    ../../system/hardware/automount.nix
    ../../system/hardware/sound.nix
    # ../../system/app/grafana.nix
    # ../../system/hardware/ydotool.nix
  ];

  # nix
  documentation.nixos.enable = false; # .desktop
  nixpkgs.config = {
    allowUnfree = true;
    rocmSupport = false; # torch broken
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

      max-jobs = systemSettings.threads;
      cores = systemSettings.threads;
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

  programs.hyprland.enable = true;
  programs.gnome-disks.enable = true;

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

      (btop.override { rocmSupport = true; })
      fzf
      kitty
      foot # BACKUP TERMINAL
      xterm # BACKUP TERMINAL

      tofi

      git-crypt
      wget
      neovim # default editor

      (pkgs.callPackage ../../system/app/sddm-astronaut.nix {
        # theme = "pixel_sakura";
      })

      # libsForQt5.qt5.qtgraphicaleffects # sddm theme dependency
      # (libsForQt5.callPackage ../../system/app/sddm-astronaut.nix { })
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
    };
    xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];
    };

    gnome.gnome-keyring.enable = true; # NOTE: Required for mysql-workbench
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

  # User account
  users.users.${userSettings.username} = {
    isNormalUser = true;
    description = userSettings.name;
    extraGroups = [
      "networkmanager"
      "wheel"
      "audio"
      "video"
      "uinput"
      "input"
      "libvirtd"
    ];
    packages = with pkgs; [ ];
    # uid = 1000;
  };

  security.pam.services.swaylock = { }; # without this swaylock is broken

  # List packages installed in system profile. To search, run:
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
