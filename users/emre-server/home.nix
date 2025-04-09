{
  pkgs,
  config,
  inputs,
  ...
}:
let
  username = "emre";
in
{
  imports = [
    (import ../common/xdg.nix {
      inherit pkgs inputs config;
      gdriveDir = "/home/${username}/Desktop/gdrive";
      dotfilesDir = "/home/${username}/Desktop/dotfiles";
    })
    ../common/sessionVariables.nix
    ../common/shellAliases.nix
  ];

  targets.genericLinux.enable = true;

  programs = {
    gpg.homedir = "${config.xdg.dataHome}/gnupg";
    home-manager.enable = true; # Let Home Manager install and manage itself.
    starship.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };
    bash = {
      enable = true;
      # historyFile = "${config.home.sessionVariables.XDG_STATE_HOME}/bash/history";
      historyFileSize = -1;
      historySize = -1;
      historyControl = [
        "ignoredups"
        "erasedups"
      ];
      enableCompletion = true;
      bashrcExtra = ''
        PROMPT_COMMAND="history -a; history -r"
      '';
      initExtra = ''
        lf_cd () {
            cd "$(command lf -print-last-dir "$@")"
        }
        yazi_cd() {
          tmp="$(mktemp -t "yazi-cwd.XXXXX")"
          yazi --cwd-file="$tmp"
          if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            cd -- "$cwd"
          fi
          rm -f -- "$tmp"
        }
        gcmp() {
          git commit -m "$1" && git push
        }
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
  services.udiskie.enable = true;
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

    stateVersion = "24.05"; # do not change

    pointerCursor = {
      gtk.enable = true;
      name = "Dracula-cursors";
      package = pkgs.dracula-theme;
      size = 10;
    };

    persistence."/persist/home" = {
      directories = [
        "Desktop"
        "Documents"
        "Downloads"
        "Videos"
        ".ssh"
        ".local/share/keyrings"
      ];
      allowOther = true;
    };
  };
  home.packages = with pkgs; [
    bandwhich # network monitoring TUI
    cpufrequtils
    hypridle
    vim # default editor
    waybar
    wttrbar
    hyprlock
    kdePackages.xwaylandvideobridge
    tor-browser
    qalculate-qt
    libqalculate
    # (lf.overrideAttrs (oldAttrs: {
    #   patches = oldAttrs.patches or [] ++ [../../system/app/lf.patch];
    # }))
    yazi
    wl-clipboard
    wl-clip-persist
    pulseaudio
    tree

    python3

    difftastic
    jq # to parse hyprctl
    usbutils
    pavucontrol
    android-tools # adb
    transmission_4-qt
    libsForQt5.kolourpaint
    libsForQt5.qt5.qtimageformats # webp support for kolourpaint
    libsForQt5.breeze-icons
    ventoy
    nwg-displays
    wlr-randr # nwg-displays dependency
    hyprshot
    networkmanagerapplet
    brightnessctl
    kooha
    swaynotificationcenter

    playerctl
    swww # for update_wp
    mpv
    ripgrep
    xdragon
    tmux
    ffmpeg-full
    ffmpegthumbnailer # for yazi opus plugin
    bat
    libnotify
    parallel-full

    imhex
    trash-cli
    unar
    zip
    ghostscript

    asm-lsp
    nixd
    nixfmt-rfc-style
    ruff
    ruff-lsp
    pyright
    clippy
    taplo
    nodePackages_latest.vscode-json-languageserver
    nodePackages_latest.bash-language-server
    shfmt
    nodePackages_latest.prettier
    clang-tools
    lldb
    cmake-language-server
    marksman
    gnumake
    yaml-language-server

    neovim
    # taskwarrior
    # timewarrior

    adb-sync
    wineWowPackages.waylandFull
    winetricks
    steam-run # quick runner for fsh compliant binaries
    udiskie
    # (pkgs.callPackage ../../pkgs/xremap.nix { })
    # (pkgs.callPackage ../../pkgs/helix.nix { })
    helix # no need for the patches
  ];
}
