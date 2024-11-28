{
  pkgs,
  userSettings,
  systemSettings,
  ...
}:
{
  imports = [
    ../../system/hardware/asustuf/hardware-configuration.nix
    ../../system/hardware/asustuf/nvidia.nix
    ../../system/hardware/battery.nix
    ../../system/hardware/virtualisation.nix
    ../../system/hardware/locale.nix
    ../../system/hardware/bootloader.nix
    ../../system/hardware/bluetooth.nix
    ../../system/hardware/network.nix
    ../../system/hardware/automount.nix
    ../../system/hardware/sound.nix
    # ../../system/hardware/ydotool.nix
  ];

  # nix
  documentation.nixos.enable = false; # .desktop
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaSupport = true;
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    settings = {
      substituters = [
        "https://cuda-maintainers.cachix.org"
        "https://openlane.cachix.org"
      ];
      trusted-public-keys = [
        "openlane.cachix.org-1:qqdwh+QMNGmZAuyeQJTH9ErW57OWSvdtuwfBKdS254E="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
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

  # packages
  environment.systemPackages = with pkgs; [
    home-manager
    git

    (btop.override { cudaSupport = true; })
    fzf
    kitty
    tofi

    git-crypt
    wget
    neovim # default editor
    libsForQt5.qt5.qtgraphicaleffects # sddm theme dependency
    (libsForQt5.callPackage ../../system/app/sddm-astronaut.nix { })
  ];

  # services
  services = {
    dbus.enable = true;
    # services.asusd.enable = true;
    # services.asusd.enableUserService = true;
    displayManager = {
      sddm = {
        enable = true;
        theme = "astronaut";
        autoNumlock = true;
        # theme = "${import ../../system/app/sddm-astronaut.nix {inherit pkgs;}}";
        # theme = "${import ../../system/app/sddm-sugar-dark.nix {inherit pkgs;}}";
      };
    };
    xserver = {
      enable = true;
      excludePackages = [ pkgs.xterm ];
    };

    gnome.gnome-keyring.enable = true; # NOTE: Required for mysql-workbench
  };

  # test: `cpupower frequency-info`
  boot = {
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

  environment.localBinInPath = true;
  environment.sessionVariables = {
    # If your cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    # Hint electron apps to use wayland
    NIXOS_OZONE_WL = "1";
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
