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
    (import ../../pkgs/firefox.nix {
      inherit username;
    })
    # ../../pkgs/derivations/thunderbird.nix
    ../../pkgs/low_battery_notify.nix

    (import ../common/xdg.nix {
      inherit pkgs inputs config;
      gdriveDir = "/home/${username}/Desktop/gdrive";
      dotfilesDir = "/home/${username}/Desktop/dotfiles";
    })
    ../common/sessionVariables.nix
    ../common/shellAliases.nix
  ];

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };

  targets.genericLinux.enable = true;

  programs = {
    gpg.homedir = "$HOME/.local/share/gnupg";
    home-manager.enable = true; # Let Home Manager install and manage itself.
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
        # volume levels
        ".config/pulse"
        ".local/state/pipewire"
        ".local/state/wireplumber"

        # generic
        ".cache"
        ".mozilla"
        # ".thunderbird" # not used anymore
        # ".local/share/keyrings"
        ".local/share"
        # ".local/state"

        "Desktop"
        "Documents"
        "Downloads"
        "Videos"
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
    # anki-bin
    # piper-tts

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
    swayosd

    playerctl
    swww # for update_wp
    activate-linux # for update_wp
    mpv
    # (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    # nerd-fonts.jetbrains-mono
    ripgrep
    # ripdrag # started to fail when nvidia gpu is enabled
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
    drawio
    yek

    rclone
    # citrix_workspace
    # helix
    # helix-gpt
    # (koboldcpp.override { cublasSupport = true; })
    # (pkgs.llama-cpp.override { cudaSupport = true; })
    # ollama-cuda
    lsp-ai
    asm-lsp
    nixd
    # alejandra
    nixfmt-rfc-style
    ruff
    ruff-lsp
    pyright
    # rustup component add rust-analyzer
    rust-analyzer
    rustfmt
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
    # markdown-oxide
    gnumake
    texlab
    sioyek
    yaml-language-server
    verible
    nodePackages.diagnostic-languageserver
    verilator

    lua-language-server
    # vale-ls
    # typos-lsp
    # ltex-ls

    neovim
    # taskwarrior
    # timewarrior

    # https://github.com/NixOS/nixpkgs/issues/47201#issuecomment-2379635080
    # colima

    udiskie
    adb-sync
    # wineWowPackages.waylandFull
    # winetricks
    # steam-run # quick runner for fsh compliant binaries

    inputs.small-apps.packages.${pkgs.system}.waybar_timer
    inputs.small-apps.packages.${pkgs.system}.gtk_applet
    inputs.small-apps.packages.${pkgs.system}.auto_refresh
    inputs.small-apps.packages.${pkgs.system}.youtube_sync
    inputs.small-apps.packages.${pkgs.system}.homepage
    # inputs.small-apps.packages.${pkgs.system}.tt
    # inputs.small-apps.packages.${pkgs.system}.clipboard_tts
    # inputs.small-apps.packages.${pkgs.system}.gtk_indicator
    # inputs.small-apps.packages.${pkgs.system}.update_wp
    # inputs.small-apps.packages.${pkgs.system}.notify_scheduler
    # inputs.small-apps.packages.${pkgs.system}.gen_typing_test

    (pkgs.callPackage ../../pkgs/xremap.nix { wlrootsSupport = true; })
    (pkgs.callPackage ../../pkgs/helix.nix { })
    # (pkgs.callPackage ../../pkgs/mitype.nix { })
    # (pkgs.callPackage ../../pkgs/rvc-cli.nix { })
    # (pkgs.callPackage ../../pkgs/blender.nix { })
    # (pkgs.callPackage ../../pkgs/veridian.nix { })
    # (pkgs.callPackage ../../system/app/svlangserver.nix {})
    # (pkgs.callPackage ../../pkgs/veridian.nix { withSlang = true; })
    # (pkgs.callPackage ../../pkgs/j4-dmenu-desktop.nix { })
  ];
}
