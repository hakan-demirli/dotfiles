{ pkgs, inputs, ... }:

let
  dev-essentials = with pkgs; [
    bat
    delta
    # difftastic
    fd
    fzf
    git
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
    asm-lsp
    clang-tools
    clippy
    cmake-language-server
    gnumake
    # inputs.small-apps.packages.${pkgs.stdenv.hostPlatform.system}.markdown-countdown-lsp
    lldb
    lsp-ai
    lua-language-server
    marksman
    nixd
    nixfmt-rfc-style
    nodePackages.diagnostic-languageserver
    nodePackages_latest.bash-language-server
    nodePackages_latest.prettier
    nodePackages_latest.vscode-json-languageserver
    pyright
    python3
    ruff
    rust-analyzer
    rustfmt
    shfmt
    taplo
    texlab
    uwu-colors
    verible
    # veridian
    verilator
    yaml-language-server
  ];

  tools-cli = with pkgs; [
    ffmpeg-full
    ffmpegthumbnailer
    ghostscript
    inputs.small-apps.packages.${pkgs.stdenv.hostPlatform.system}.difffenced
    mutagen
    ouch
    rsync
    # unar
    zip
    openssl
  ];

  server-cli =
    with pkgs;
    [
      adb-sync
      android-tools
      bandwhich
      usbutils
    ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 cpufrequtils;

  desktop-cli = with pkgs; [
    inputs.small-apps.packages.${pkgs.stdenv.hostPlatform.system}.auto_refresh
    inputs.small-apps.packages.${pkgs.stdenv.hostPlatform.system}.youtube_sync
    libnotify
    # libqalculate
    pavucontrol
    (pkgs.callPackage ../../pkgs/libqalculate-fzf.nix { })
    pulseaudio
    xremap
  ];

  gui = with pkgs; [
    anki-bin
    brightnessctl
    drawio
    exfatprogs
    hypridle
    hyprlock
    hyprshot
    # imhex
    inputs.small-apps.packages.${pkgs.stdenv.hostPlatform.system}.gtk_applet
    inputs.small-apps.packages.${pkgs.stdenv.hostPlatform.system}.waybar_timer
    kdePackages.breeze-icons
    kdePackages.kolourpaint
    kdePackages.qtimageformats
    kooha
    localsend
    mpv
    networkmanagerapplet
    nwg-displays
    inputs.small-apps.packages.${pkgs.stdenv.hostPlatform.system}.nix-treemap
    (pkgs.callPackage ../../pkgs/gparted.nix { })
    playerctl
    qalculate-qt
    sioyek
    swaynotificationcenter
    swayosd
    swww
    tailscale-systray
    tor-browser
    transmission_4-qt
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
    ;
}
