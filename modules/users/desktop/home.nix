{
  inputs,
  ...
}:
let
  username = "emre";

  flake.modules.homeManager.desktop =
    { config, pkgs, ... }:
    let
      koohaDocsPath = "${config.home.homeDirectory}/Documents";
      historyFile = "$HOME/.local/state/bash/history";
      mkRawGVariant = rawString: {
        _type = "gvariant";
        type = "s";
        value = rawString;
        __toString = self: self.value;
      };
      common-packages = import (inputs.self + /pkgs/common/packages.nix) { inherit pkgs inputs; };
    in
    {
      imports = [
        (import (inputs.self + /pkgs/firefox.nix) { inherit username; })
        (inputs.self + /pkgs/low_battery_notify.nix)
        (import (inputs.self + /pkgs/common/xdg.nix) {
          inherit pkgs inputs config;
          desktopDir = "/home/${username}/Desktop/";
        })
        (import (inputs.self + /pkgs/common/bash.nix) {
          bashConfigDir = inputs.self + /.config/bash;
          inherit historyFile;
        })
      ];

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
            file_manager = "${pkgs.kitty}/bin/kitty -e ${pkgs.yazi}/bin/yazi";
          };
        };
      };

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
        gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
        gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      };

      qt = {
        enable = true;
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
    };
in
{
  inherit flake;
}
