# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
    ./nvidia.nix
    inputs.xremap-flake.nixosModules.default
  ];

  hardware.uinput.enable = true;
  services.xremap = {
    withWlroots = true;
    # userName = "emre";
    yamlConfig = builtins.readFile ../.config/xremap/config.yml;
  };

  # services.auto-epp.enable = true;
  services.tlp = {
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

  # test: `cpupower frequency-info`
  boot = {
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

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    users = {
      emre = import ../home.nix;
    };
    useGlobalPkgs = true;
  };

  time.hardwareClockInLocalTime = true;

  networking.hostName = "nixos"; # Define your hostname.

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
  services.dbus.enable = true;
  services.udisks2.enable = true;
  programs.gnome-disks.enable = true;

  # For Asusctl
  # services.asusd.enable = true;
  # services.asusd.enableUserService = true;

  # Enable networking
  networking.networkmanager.enable = true;
  hardware = {
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
  services.blueman.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Istanbul";

  nix.settings.experimental-features = ["nix-command" "flakes"];
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    displayManager = {
      sddm = {
        enable = true;
        theme = "${import ../programs/sddm-theme.nix {inherit pkgs;}}";
      };
    };
  };
  # https://github.com/NixOS/nixpkgs/issues/97795#issuecomment-693354398
  systemd.services.display-manager.wants = ["systemd-user-sessions.service" "multi-user.target" "network-online.target"];
  systemd.services.display-manager.after = ["systemd-user-sessions.service" "multi-user.target" "network-online.target"];

  # Configure keymap in X11
  # services.xserver = {
  #   layout = "us";
  #   xkbVariant = "";
  # };

  # Enable CUPS to print documents.
  services.printing.enable = true;

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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.emre = {
    isNormalUser = true;
    description = "emre";
    extraGroups = ["networkmanager" "wheel" "video" "uinput" "input"];
    packages = with pkgs; [];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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

  programs.hyprland.enable = true;

  security.pam.services.swaylock = {}; # without this swaylock is broken

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    cpufrequtils
    home-manager
    swaylock
    vim # default editor
    git
    git-crypt
    waybar
    kitty
    wofi
    firefox
    (lf.overrideAttrs (oldAttrs: {
      patches = oldAttrs.patches or [] ++ [../programs/lf.patch];
    }))
    wl-clipboard
    wl-clip-persist
    pulseaudio

    libsForQt5.qt5.qtgraphicaleffects # sddm theme dependency
  ];
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
