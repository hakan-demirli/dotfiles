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
    starship.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };
    bash = {
      enable = true;
      historyFile = "$HOME/.local/state/bash/history";
      historyFileSize = -1;
      historySize = -1;
      historyControl = [
        "ignoredups"
        "erasedups"
      ];
      enableCompletion = true;
      bashrcExtra = ''
        PROMPT_COMMAND="history -a; history -n"
      '';
      initExtra = ''
        if [ -f "${bashConfigDir}/main.sh" ]; then
          source "${bashConfigDir}/main.sh"
        fi
      '';
    };
    fzf = {
      enable = true;
      defaultCommand = "${pkgs.fd}/bin/fd --type f";
      defaultOptions = [
        "--bind 'tab:toggle-up,btab:toggle-down'"
        "--info=inline"
        "--border"
        "--color=fg:-1,bg:-1,hl:#bd93f9"
        "--color=fg+:#f8f8f2,bg+:#282a36,hl+:#bd93f9"
        "--color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6"
        "--color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
        "--prompt='❯ '"
      ];
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
