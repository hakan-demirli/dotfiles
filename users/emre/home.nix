{
  pkgs,
  config,
  inputs,
  lib,
  ...
}:
let
  username = "emre";
  koohaDocsPath = "${config.home.homeDirectory}/Documents";
  bashConfigDir = ../../.config/bash;
  historyFile = "$HOME/.local/state/bash/history";
  mkRawGVariant = rawString: {
    _type = "gvariant";
    type = "s";
    value = rawString;
    __toString = self: self.value;
  };
  common-packages = import ../common/packages.nix { inherit pkgs inputs; };
in
{
  imports = [
    (import ../../pkgs/firefox.nix {
      inherit username;
    })
    # ../../pkgs/derivations/thunderbird.nix
    ../../pkgs/low_battery_notify.nix

    (import ../common/xdg.nix {
      inherit pkgs inputs config;
      desktopDir = "/home/${username}/Desktop/";
    })
    (import ../common/bash.nix { inherit bashConfigDir historyFile; })
  ];

  # dconf dump / | dconf2nix > dconf.nix
  dconf.settings = {
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";

    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };

    "io/github/seadve/Kooha" = {
      capture-mode = "monitor-window";
      framerate = lib.hm.gvariant.mkTuple [
        20
        1
      ];
      profile-id = "matroska-h264";
      record-delay = lib.hm.gvariant.mkUint32 3;
      saving-location = mkRawGVariant "b'${koohaDocsPath}'";
      screencast-restore-token = "";
    };
  };

  targets.genericLinux.enable = true;

  programs = {
    gpg.homedir = "$HOME/.local/share/gnupg";
    home-manager.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };
  };
  services.udiskie = {
    enable = true;
    automount = true;
    settings = {
      program_options = {
        # file_manager = "${pkgs.xdg-utils}/bin/xdg-open";
        file_manager = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi";
      };
    };
  };
  # https://github.com/nix-community/home-manager/issues/2064
  systemd.user.targets.tray.Unit.Requires = [ "graphical-session.target" ];

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
    # gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
  qt = {
    enable = true;
    #useGtkTheme = true;
    platformTheme.name = "gtk";
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.05";
    pointerCursor = {
      gtk.enable = true;
      name = "Dracula-cursors";
      package = pkgs.dracula-theme;
      size = 10;
    };
  };
  home.packages =
    common-packages.dev-essentials
    ++ common-packages.editors
    ++ common-packages.lsp
    ++ common-packages.server-cli
    ++ common-packages.desktop-cli
    ++ common-packages.ai
    ++ common-packages.gui
    ++ common-packages.tools-cli;
}
