{
  pkgs,
  lib,
  config,
  facts,
  inputs,
  ...
}:
let
  theme = import ../theme.nix;

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
    (import ../pkgs/nix/github_backup.nix { })
    ../pkgs/nix/screen-record.nix
  ]
  ++ lib.optional ((facts.location.kind or null) == "laptop") ../pkgs/nix/low_battery_notify.nix;

  home = {
    file = {
      ".local/state/bash".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Desktop/infra/state/.local/state/bash";
      ".local/share/scratchpads".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Desktop/infra/state/scratchpads";
      ".ssh/config".source = ../config/ssh/config;

      ".claude/settings.json" = lib.mkIf (builtins.pathExists ../config/claude/settings.json) {
        source = ../config/claude/settings.json;
      };
    };

    pointerCursor = {
      enable = true;
      name = "Dracula-cursors";
      package = pkgs.dracula-theme;
      size = 24;
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

        font = {
          normal.family = theme.font.family.mono;
          size = 11.0;
        };

        colors = {
          primary = {
            background = theme.dracula.background;
            foreground = theme.dracula.foreground;
          };
          cursor = {
            text = theme.dracula.background;
            cursor = theme.dracula.foreground;
          };
          selection = {
            text = theme.dracula.foreground;
            background = theme.dracula.selection;
          };
          normal = {
            inherit (theme.ansi)
              black
              red
              green
              yellow
              blue
              magenta
              cyan
              white
              ;
          };
          bright = {
            black = theme.ansi.brightBlack;
            red = theme.ansi.brightRed;
            green = theme.ansi.brightGreen;
            yellow = theme.ansi.brightYellow;
            blue = theme.ansi.brightBlue;
            magenta = theme.ansi.brightMagenta;
            cyan = theme.ansi.brightCyan;
            white = theme.ansi.brightWhite;
          };
        };
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

  fonts.fontconfig.enable = true;

  gtk = {
    enable = true;
    font = {
      package = pkgs.roboto;
      name = theme.font.family.plain;
      size = theme.font.scale.bodyMedium.size;
    };
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
      size = 24;
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
    dataFile.applications = lib.mkIf (builtins.pathExists ../config/desktop_files) {
      source = ../config/desktop_files;
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
