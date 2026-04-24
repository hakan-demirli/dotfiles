{ pkgs, inputs, ... }:

let
  nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };

  dev-essentials = with pkgs; [
    bat
    delta
    # difftastic
    fd
    fzf
    git
    gh
    jq
    parallel-full
    ripgrep
    tmux
    trash-cli
    tree
    yazi
    yek
    starship
  ];

  gaming = with pkgs; [
    winetricks
    wineWow64Packages.wayland
    umu-launcher
    gamescope
    mangohud
    (nurPkgs.umu-fzf or null)
  ];

  editors = with pkgs; [
    helix
    neovim
    vim
  ];

  ai = with pkgs; [
    aider-chat
    aichat
    opencode
    claude-code
  ];

  lsp =
    with pkgs;
    [
      asm-lsp
      bash-language-server
      clang-tools
      clippy
      cmake-language-server
      diagnostic-languageserver
      gnumake
      # inputs.nur.packages.${pkgs.stdenv.hostPlatform.system}.markdown-countdown-lsp
      lldb
      # lsp-ai
      lua-language-server
      marksman
      nixd
      nixfmt
      prettier
      pyright
      python3
      ruff
      rust-analyzer
      rustfmt
      shfmt
      taplo
      texlab
      uwu-colors
      # veridian
      verilator
      vscode-json-languageserver
      yaml-language-server
    ]
    ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
      verible
    ];

  tools-cli =
    with pkgs;
    lib.filter (x: x != null) [
      ffmpeg-full
      ffmpegthumbnailer
      ghostscript
      (nurPkgs.dap or null)
      (nurPkgs.uncomment or null)
      (nurPkgs.flake-updater or null)
      (nurPkgs.riveroftime or null)
      # mutagen
      ouch
      rsync
      curl
      wget
      file
      # unar
      zip
      unzip
      p7zip
      openssl
    ];

  server-cli =
    with pkgs;
    [
      btop
      systemctl-tui
      bandwhich
      usbutils
    ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 cpufrequtils;

  desktop-cli =
    with pkgs;
    lib.filter (x: x != null) [
      (nurPkgs.auto_refresh or null)
      (nurPkgs.youtube_sync or null)
      adb-sync
      android-tools
      libnotify
      # libqalculate
      pavucontrol
      (pkgs.callPackage ../../pkgs/libqalculate-fzf.nix { })
      pulseaudio
      xremap
    ];

  gui =
    with pkgs;
    lib.filter (x: x != null) [
      anki-bin
      brightnessctl
      drawio
      exfatprogs
      hypridle
      hyprlock
      # hyprshot
      grim
      slurp
      wayscriber
      # imhex
      (nurPkgs.gtk_applet or null)
      (nurPkgs.waybar_timer or null)
      kdePackages.breeze-icons
      kdePackages.kolourpaint
      kdePackages.qtimageformats
      kooha
      localsend
      mpv
      networkmanagerapplet
      nwg-displays
      (nurPkgs.nix-treemap or null)
      (pkgs.callPackage ../../pkgs/gparted.nix { })
      playerctl
      qalculate-qt
      sioyek
      swaynotificationcenter
      swayosd
      awww
      tailscale-systray
      tor-browser
      transmission_4-qt
      (pkgs.callPackage ../../pkgs/ttf-wps-fonts.nix { })
      udiskie
      waybar
      wl-clipboard
      wl-clip-persist
      wlr-randr
      wttrbar
      dragon-drop
    ];

in
{
  inherit
    ai
    desktop-cli
    dev-essentials
    editors
    gui
    lsp
    server-cli
    tools-cli
    gaming
    ;
}
