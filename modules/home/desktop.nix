{
  pkgs,
  lib,
  config,
  facts,
  inputs,
  ...
}:
let
  nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };
  pickNur = name: nurPkgs.${name} or null;

  immutableConfigEntries = [
    "activitywatch"
    "aichat"
    "aider"
    "anyrun"
    "awatcher"
    "wayscriber"
    "bat"
    "bash"
    "btop"
    "cargo"
    "clangd"
    "firefoxcss"
    "gdb"
    "gdb-dashboard"
    "git"
    "gnome3-keybind-backup"
    "gnome-extensions"
    "gtk_indicator"
    "helix"
    "hypr"
    "input-remapper-2"
    "kitty"
    "lazygit"
    "lesskey"
    "lf"
    "mimeapps.list"
    "mpd"
    "mpv"
    "nix"
    "npm"
    "nwg"
    "claude"
    "parallel"
    "piper"
    "qalculate"
    "qmk"
    "QtProject"
    "quantifyself"
    "qutebrowser"
    "repx"
    "rmpc"
    "sioyek"
    "ssh"
    "starship.toml"
    "swaync"
    "tmux"
    "tmuxp"
    "tofi"
    "transmission"
    "vim"
    "wavemon"
    "waybar"
    "wgetrc"
    "wofi"
    "xdg-desktop-portal-termfilechooser"
    "xilinx"
    "xremap"
    "yazi"
    "zathura"
  ];

  mkImmutable =
    name:
    let
      src = ./config + "/${name}";
    in
    lib.optionalAttrs (builtins.pathExists src) {
      ${name} = {
        source = src;
        recursive = true;
      };
    };

  desktop-cli =
    with pkgs;
    lib.filter (x: x != null) [
      adb-sync
      android-tools
      libnotify
      libqalculate-fzf
      pavucontrol
      pulseaudio
      xremap
      (pickNur "auto_refresh")
      (pickNur "youtube_sync")
      (pickNur "riveroftime")
    ];

  gui =
    with pkgs;
    lib.filter (x: x != null) [
      anki-bin
      awww
      brightnessctl
      dragon-drop
      drawio
      exfatprogs
      feh
      grim
      gparted-emre
      hypridle
      hyprlock
      kdePackages.breeze-icons
      kdePackages.kolourpaint
      kdePackages.qtimageformats
      kooha
      localsend
      moonlight-qt
      mpv
      nautilus
      networkmanagerapplet
      nwg-displays
      playerctl
      qalculate-qt
      qutebrowser
      sioyek
      slurp
      swaynotificationcenter
      swayosd
      tailscale-systray
      tor-browser
      transmission_4-qt
      ttf-wps-fonts
      udiskie
      waybar
      wayscriber
      wl-clip-persist
      wl-clipboard
      wlr-randr
      wttrbar
      zathura
      (pickNur "gtk_applet")
      (pickNur "waybar_timer")
      (pickNur "nix-treemap")
    ];

  gaming =
    with pkgs;
    [
      gamescope
      mangohud
      umu-launcher
      winetricks
      wineWow64Packages.wayland
    ]
    ++ lib.optional (pickNur "umu-fzf" != null) (pickNur "umu-fzf");

  remotedesktopHost = with pkgs; [
    sunshine
    libva-utils
    mesa-demos
    vulkan-tools
    wayland-utils
  ];

  mkRawGVariant = rawString: {
    _type = "gvariant";
    type = "s";
    value = rawString;
    __toString = self: self.value;
  };
in
{
  imports = [
    ./headless.nix

    (import ./pkgs/nix/firefox.nix { username = "emre"; })
    ./pkgs/nix/activitywatch.nix
    (import ./pkgs/nix/state_autocommit.nix { })
    (import ./pkgs/nix/ntfy-listener.nix { })
    (import ./pkgs/nix/opencode.nix { })
    (import ./pkgs/nix/github_backup.nix { })
  ]
  ++ lib.optional ((facts.location.kind or null) == "laptop") ./pkgs/nix/low_battery_notify.nix;

  home = {
    packages = desktop-cli ++ gui ++ gaming ++ remotedesktopHost;

    file = {
      ".local/bin" = lib.mkIf (builtins.pathExists ./pkgs/bin) {
        source = ./pkgs/bin;
        recursive = true;
        executable = true;
      };

      ".aider.conf.yml" = lib.mkIf (builtins.pathExists ./config/aider/.aider.conf.yml) {
        source = ./config/aider/.aider.conf.yml;
      };
      ".claude/settings.json" = lib.mkIf (builtins.pathExists ./config/claude/settings.json) {
        source = ./config/claude/settings.json;
      };
    };

    sessionVariables.EMRE_HOME_HOST_ID = facts.id;

    pointerCursor = {
      gtk.enable = true;
      name = "Dracula-cursors";
      package = pkgs.dracula-theme;
      size = 10;
    };
  };

  programs = {
    alacritty = {
      enable = true;
      settings = {
        window.padding = {
          x = 6;
          y = 6;
        };
        font.size = 11.0;
      };
    };

    gpg.homedir = "${config.home.homeDirectory}/.local/share/gnupg";
    home-manager.enable = true;
  };

  services.udiskie = {
    enable = true;
    automount = true;
    settings = {
      program_options = {
        file_manager = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi";
      };
    };
  };

  systemd.user.targets.tray.Unit.Requires = [ "graphical-session.target" ];

  targets.genericLinux.enable = true;

  gtk = {
    enable = true;
    theme = {
      package = pkgs.dracula-theme;
      name = "Dracula";
    };
    iconTheme = {
      package = pkgs.dracula-icon-theme;
      name = "Dracula";
    };
    cursorTheme = {
      name = "Dracula-cursors";
      package = pkgs.dracula-theme;
      size = 10;
    };
    gtk4 = {
      inherit (config.gtk) theme;
      extraConfig.gtk-application-prefer-dark-theme = true;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
  };

  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";

    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };

    "io/github/seadve/Kooha" = {
      capture-mode = "monitor-window";
      framerate = inputs.home-manager.lib.hm.gvariant.mkTuple [
        20
        1
      ];
      profile-id = "matroska-h264";
      record-delay = inputs.home-manager.lib.hm.gvariant.mkUint32 3;
      saving-location = mkRawGVariant "b'${config.home.homeDirectory}/Documents'";
      screencast-restore-token = "";
    };
  };

  xdg = {
    configFile = lib.foldl' (acc: n: acc // (mkImmutable n)) { } immutableConfigEntries;

    dataFile.applications = lib.mkIf (builtins.pathExists ./config/desktop_files) {
      source = ./config/desktop_files;
      recursive = true;
    };

    dataFile.fonts = lib.mkIf (builtins.pathExists ./config/fonts) {
      source = ./config/fonts;
      recursive = true;
    };

    portal = {
      enable = true;
      xdgOpenUsePortal = true;
      config = {
        common = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
          "org.freedesktop.impl.portal.GlobalShortcuts" = [ "hyprland" ];
        };
        hyprland = {
          "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
          default = [
            "hyprland"
            "gtk"
          ];
        };
      };
      extraPortals = [
        pkgs.xdg-desktop-portal-termfilechooser
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-wlr
        pkgs.xdg-desktop-portal-hyprland
      ];
    };
  };
}
