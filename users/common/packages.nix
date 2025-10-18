{ pkgs, inputs, ... }:

let
  dev-essentials = with pkgs; [
    bat
    difftastic
    fd
    fzf
    git
    jq
    ripgrep
    tmux
    trash-cli
    tree
    parallel-full
    yazi
    yek
  ];

  editors = with pkgs; [
    helix
    neovim
    vim
  ];

  ai = with pkgs; [
    aider-chat
    aichat
  ];

  lsp = with pkgs; [
    nixd
    nixfmt-rfc-style

    python3
    pyright
    ruff

    rust-analyzer
    rustfmt
    clippy

    clang-tools
    lldb

    nodePackages_latest.bash-language-server
    nodePackages_latest.prettier
    nodePackages_latest.vscode-json-languageserver
    marksman
    shfmt
    taplo
    yaml-language-server

    cmake-language-server
    gnumake
    lua-language-server
    verible
    verilator

    uwu-colors
    lsp-ai
    asm-lsp
    texlab
    nodePackages.diagnostic-languageserver
    veridian
    # inputs.small-apps.packages.${pkgs.system}.markdown-countdown-lsp
  ];

  tools-cli = with pkgs; [
    rsync
    ffmpeg-full
    ffmpegthumbnailer
    ghostscript
    ouch
    # unar
    zip
    mutagen
    inputs.small-apps.packages.${pkgs.system}.difffenced
  ];

  server-cli =
    with pkgs;
    [
      android-tools
      bandwhich
      usbutils
      adb-sync
    ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 cpufrequtils;

  desktop-cli = with pkgs; [
    pavucontrol
    libnotify
    pulseaudio
    libqalculate
    xremap
    inputs.small-apps.packages.${pkgs.system}.auto_refresh
    inputs.small-apps.packages.${pkgs.system}.youtube_sync
  ];

  gui = with pkgs; [
    waybar
    wttrbar
    hyprlock
    hypridle
    hyprshot
    swww
    wl-clipboard
    wl-clip-persist
    brightnessctl
    networkmanagerapplet
    swaynotificationcenter
    swayosd
    nwg-displays
    wlr-randr
    anki-bin
    drawio
    imhex
    kdePackages.kolourpaint
    kdePackages.breeze-icons
    kdePackages.qtimageformats
    kooha
    mpv
    playerctl
    qalculate-qt
    sioyek
    tor-browser
    transmission_4-qt
    udiskie
    xdragon
    (pkgs.callPackage ../../pkgs/gparted.nix { })
    exfatprogs
    tailscale-systray
    inputs.small-apps.packages.${pkgs.system}.waybar_timer
    inputs.small-apps.packages.${pkgs.system}.gtk_applet

    kdePackages.xwaylandvideobridge
  ];

in
{
  inherit
    dev-essentials
    editors
    lsp
    server-cli
    desktop-cli
    ai
    gui
    tools-cli
    ;
}
