{
  pkgs,
  lib,
  config,
  facts,
  inputs,
  ...
}:
let
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
