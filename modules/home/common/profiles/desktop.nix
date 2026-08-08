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

  autoRefresh = pkgs.writeShellApplication {
    name = "auto_refresh";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../pkgs/bin/auto_refresh.py} "$@"
    '';
  };

  hpPowerMenu = pkgs.writeTextDir "share/hp-power/menu.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <object class="GtkMenu" id="menu">
        <style>
          <class name="touch-menu" />
        </style>
        <child>
          <object class="GtkMenuItem" id="turbo">
            <property name="label">Turbo</property>
          </object>
        </child>
        <child>
          <object class="GtkMenuItem" id="balanced">
            <property name="label">Balanced</property>
          </object>
        </child>
        <child>
          <object class="GtkMenuItem" id="silent">
            <property name="label">Silent</property>
          </object>
        </child>
      </object>
    </interface>
  '';

  immutableConfigEntries = [
    "aichat"
    "aider"
    "anyrun"
    "awatcher"
    "bash"
    "bat"
    "btop"
    "cargo"
    "clangd"
    "claude"
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
    "parallel"
    "piper"
    "qalculate"
    "qmk"
    "QtProject"
    "quantifyself"
    "qutebrowser"
    "repx"
    "rmpc"
    "sccache"
    "sioyek"
    "starship.toml"
    "swaync"
    "tmux"
    "tmuxp"
    "tofi"
    "transmission"
    "vim"
    "wavemon"
    "waybar"
    "wayscriber"
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
      src = ../config + "/${name}";
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
      exfatprogs
      android-tools
      hpPowerMenu
      libnotify
      libqalculate-fzf
      pavucontrol
      pulseaudio
      xremap
      autoRefresh
      (pickNur "youtube_sync")
      (pickNur "riveroftime")
    ];

  gui =
    with pkgs;
    lib.filter (x: x != null) [
      awww
      brightnessctl
      dragon-drop
      drawio
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
      networkmanagerapplet
      nwg-displays
      playerctl
      qalculate-qt
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

    (import ../pkgs/nix/firefox.nix { username = "emre"; })
    (import ../pkgs/nix/state_autocommit.nix { })
    (import ../pkgs/nix/ntfy-listener.nix { })
    (import ../pkgs/nix/opencode.nix { })
    (import ../pkgs/nix/github_backup.nix { })
  ]
  ++ lib.optional ((facts.location.kind or null) == "laptop") ../pkgs/nix/low_battery_notify.nix;

  home = {
    packages = desktop-cli ++ gui ++ gaming ++ remotedesktopHost;

    file = {
      ".local/state/bash".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Desktop/infra/state/.local/state/bash";
      ".local/share/scratchpads".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Desktop/infra/state/scratchpads";
      ".ssh/config".source = ../config/ssh/config;

      ".local/bin" = lib.mkIf (builtins.pathExists ../pkgs/bin) {
        source = ../pkgs/bin;
        recursive = true;
        executable = true;
      };

      ".claude/settings.json" = lib.mkIf (builtins.pathExists ../config/claude/settings.json) {
        source = ../config/claude/settings.json;
      };
    };

    sessionVariables.EMRE_HOME_HOST_ID = facts.id;

    pointerCursor = {
      enable = true;
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
    platformTheme.name = "gtk3";
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

    dataFile.applications = lib.mkIf (builtins.pathExists ../config/desktop_files) {
      source = ../config/desktop_files;
      recursive = true;
    };

    dataFile.fonts = lib.mkIf (builtins.pathExists ../config/fonts) {
      source = ../config/fonts;
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
