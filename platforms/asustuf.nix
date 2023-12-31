{
  pkgs,
  username,
  ...
}: {
  imports = [
    ./modules/asustuf.nix
    ./modules/nvidia.nix
    ./modules/locale.nix
  ];

  # nix
  documentation.nixos.enable = false; # .desktop
  nixpkgs.config.allowUnfree = true;
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
    };
  };

  # virtualisation
  programs.virt-manager.enable = true;
  virtualisation = {
    podman.enable = true;
    libvirtd.enable = true;
  };

  programs.hyprland.enable = true;

  # packages
  environment.systemPackages = with pkgs; [
    home-manager
    git
    git-crypt
    wget
    neovim # default editor
    libsForQt5.qt5.qtgraphicaleffects # sddm theme dependency
  ];

  # services
  services = {
    blueman.enable = true;
    dbus.enable = true;
    udisks2.enable = true;
    printing.enable = false; # Enable CUPS to print documents.
    # services.asusd.enable = true;
    # services.asusd.enableUserService = true;
    flatpak.enable = true;
    xserver = {
      enable = true;
      excludePackages = [pkgs.xterm];

      displayManager = {
        sddm = {
          enable = true;
          theme = "${import ../programs/sddm-theme.nix {inherit pkgs;}}";
        };
      };
    };
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";

        CPU_MIN_PERF_ON_AC = 0;
        CPU_MAX_PERF_ON_AC = 100;
        CPU_MIN_PERF_ON_BAT = 0;
        CPU_MAX_PERF_ON_BAT = 20;
      };
    };
  };

  # test: `cpupower frequency-info`
  boot = {
    tmp.cleanOnBoot = true;
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "quiet"
      "mitigations=off"
      # "initcall_blacklist=acpi_cpufreq_init"
      # "amd_pstate.shared_mem=1"
      # "amd_pstate=active"
    ];
    # Pstates are not working
    # kernelModules = ["amd-pstate"];

    # kernelPatches = [
    #   {
    #     name = "crashdump-config";
    #     patch = null;
    #     # check via: zcat /proc/config.gz
    #     extraConfig = ''
    #       CC_OPTIMIZE_FOR_PERFORMANCE y
    #       X86_AMD_PSTATE y
    #     '';
    #   }
    # ];
    supportedFilesystems = ["ntfs"];
  };
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.default = "saved";
  boot.loader.efi.canTouchEfiVariables = true;

  time.hardwareClockInLocalTime = false; # messes clock on windows

  # systemctl status --user polkit-gnome-authentication-agent-1
  # systemctl restart --user polkit-gnome-authentication-agent-1
  security.polkit.enable = true;
  systemd = {
    user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
  programs.gnome-disks.enable = true;

  # Enable networking
  networking.networkmanager.enable = true;
  networking.hostName = "nixos"; # Define your hostname.
  hardware = {
    uinput.enable = true; # xremap dep
    bluetooth.enable = true;
    bluetooth.powerOnBoot = false;
    bluetooth = {
      settings = {
        General = {
          ControllerMode = "dual";
          FastConnectable = "true";
          Experimental = "true";
        };
        Policy = {
          AutoEnable = "false";
        };
      };
    };
  };

  # https://github.com/NixOS/nixpkgs/issues/97795#issuecomment-693354398
  systemd.services.display-manager.wants = ["systemd-user-sessions.service" "multi-user.target" "network-online.target"];
  systemd.services.display-manager.after = ["systemd-user-sessions.service" "multi-user.target" "network-online.target"];

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  users.users.${username} = {
    isNormalUser = true;
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

  ## xdg terminal chooser
  # xdg.portal = {
  #   # enable = true;
  #   extraPortals = with pkgs; [
  #     #xdg-desktop-portal-shana
  #     #xdg-desktop-portal-gtk
  #     (callPackage ../programs/xdg-desktop-portal-termfilechooser.nix {})
  #   ];
  # };
  # # needed by termfilechooser portal
  # environment.sessionVariables.TERMCMD = "${pkgs.kitty}/bin/kitty --class=file_chooser --override background_opacity=1";

  environment.localBinInPath = true;
  environment.sessionVariables = {
    # If your cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    # Hint electron apps to use wayland
    NIXOS_OZONE_WL = "1";
  };

  security.pam.services.swaylock = {}; # without this swaylock is broken

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "ondemand";
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
