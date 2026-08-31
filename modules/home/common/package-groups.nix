{
  inputs,
  lib,
  pkgs,
}:
let
  nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };
  pickNur = name: nurPkgs.${name} or null;
  sendToLaptop = pkgs.callPackage ./pkgs/nix/send-to-laptop.nix { };

  autoRefresh = pkgs.writeShellApplication {
    name = "auto_refresh";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./pkgs/bin/auto_refresh.py} "$@"
    '';
  };

in
rec {
  minimal = with pkgs; [
    btop
    curl
    delta
    git
    jq
    python3
    rsync
    vim
  ];

  developmentAdditions =
    with pkgs;
    lib.filter (package: package != null) (
      [
        aichat
        asm-lsp
        bandwhich
        bash-language-server
        bat
        cargo
        clang-tools
        claude-code
        clippy
        cmake-language-server
        diagnostic-languageserver
        fd
        ffmpeg-full
        ffmpegthumbnailer
        file
        ghostscript
        gnumake
        helix
        htop
        lldb
        lua-language-server
        marksman
        nixd
        nixfmt
        openssl
        ouch
        p7zip
        parallel-full
        prettier
        pyright
        ripgrep
        ruff
        rustc
        rust-analyzer
        rustfmt
        sendToLaptop
        shfmt
        systemctl-tui
        taplo
        texlab
        trash-cli
        tree
        unzip
        usbutils
        uwu-colors
        verilator
        vscode-langservers-extracted
        wget
        yaml-language-server
        yek
        zip
        (pickNur "uncomment")
        (pickNur "flake-updater")
        (pickNur "raider")
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ verible ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [ cpufrequtils ]
    );

  development = minimal ++ developmentAdditions;

  headlessAdditions = with pkgs; [ lazygit ];
  headless = development ++ headlessAdditions;

  desktopAdditions =
    with pkgs;
    lib.filter (package: package != null) [
      adb-sync
      android-tools
      autoRefresh
      awww
      brightnessctl
      dragon-drop
      drawio
      exfatprogs
      feh
      gamescope
      grim
      hypridle
      hyprlock
      kdePackages.breeze-icons
      kdePackages.kolourpaint
      kdePackages.qtimageformats
      kooha
      libnotify
      libqalculate-fzf
      libva-utils
      localsend
      mangohud
      material-symbols
      mesa-demos
      moonlight-qt
      mpv
      nerd-fonts.symbols-only
      networkmanagerapplet
      nwg-displays
      oskd
      pavucontrol
      playerctl
      pulseaudio
      qalculate-qt
      quickshell
      roboto
      sioyek
      slurp
      sunshine
      swayosd
      tailscale-systray
      tor-browser
      transmission_4-qt
      ttf-wps-fonts
      udiskie
      umu-launcher
      vulkan-tools
      wayland-utils
      wayscriber
      winetricks
      wineWow64Packages.wayland
      wl-clip-persist
      wl-clipboard
      wlr-randr
      wttrbar
      xremap
      xwayland-satellite
      (pickNur "youtube_sync")
      (pickNur "riveroftime")
      (pickNur "gtk_applet")
      (pickNur "nix-treemap")
      (pickNur "umu-fzf")
    ];

  desktop = headless ++ desktopAdditions;
  "headless-minimal" = minimal;
}
