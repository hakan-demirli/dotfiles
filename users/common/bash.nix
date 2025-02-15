{ config, pkgs, ... }:
rec {
  home.packages = with pkgs; [
    # awatcher
    # aw-watcher-afk
    # aw-watcher-window
    # aw-server-rust
    # (pkgs.callPackage ../../system/app/aw-manager.nix { })
    # (pkgs.callPackage ../../system/app/aw-watchers-mine.nix { })

    # (pkgs.callPackage ../../system/app/prometheus-exporters.nix { })
    #
    (pkgs.callPackage ../../pkgs/derivations/quantifyself.nix { })
    (pkgs.callPackage ../../pkgs/derivations/quantifyself-webui.nix { })
    (pkgs.callPackage ../../pkgs/derivations/html-preview-lsp.nix { })
    (pkgs.callPackage ../../pkgs/derivations/html-preview-server.nix { })

    bandwhich # network monitoring TUI
    cpufrequtils
    hypridle
    vim # default editor
    waybar
    wttrbar
    hyprlock
    xwaylandvideobridge
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
    anki-bin
    piper-tts

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

    rclone
    # citrix_workspace
    # helix
    # helix-gpt
    # (koboldcpp.override { cublasSupport = true; })
    # (pkgs.llama-cpp.override { cudaSupport = true; })
    ollama-cuda
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

    adb-sync
    wineWowPackages.waylandFull
    winetricks
    steam-run # quick runner for fsh compliant binaries
    udiskie
    # (pkgs.callPackage ../../pkgs/derivations/tt.nix {})
    # (pkgs.callPackage ../../pkgs/derivations/j4-dmenu-desktop.nix { })
    (pkgs.callPackage ../../pkgs/derivations/waybar_timer.nix { })
    (pkgs.callPackage ../../pkgs/derivations/xremap.nix { })

    (pkgs.callPackage ../../pkgs/derivations/helix.nix { })
    (pkgs.callPackage ../../pkgs/derivations/mitype.nix { })
    # (pkgs.callPackage ../../pkgs/derivations/rvc-cli.nix { })
    (pkgs.callPackage ../../pkgs/derivations/gen_typing_test.nix { })
    # (pkgs.callPackage ../../pkgs/derivations/notify_scheduler.nix { })
    # (pkgs.callPackage ../../pkgs/derivations/blender.nix { })

    (pkgs.callPackage ../../pkgs/derivations/veridian.nix { })
    # (pkgs.callPackage ../../pkgs/derivations/veridian.nix { withSlang = true; })
    (pkgs.callPackage ../../pkgs/derivations/update_wp.nix { })
    (pkgs.callPackage ../../pkgs/derivations/gtk_applet.nix { })
    (pkgs.callPackage ../../pkgs/derivations/gtk_indicator.nix { })
    # (pkgs.callPackage ../../system/app/svlangserver.nix {})
    (pkgs.callPackage ../../pkgs/derivations/youtube_sync.nix { })
    (pkgs.callPackage ../../pkgs/derivations/auto_refresh.nix { })
    (pkgs.callPackage ../../pkgs/derivations/clipboard_tts.nix { })
  ];
}
