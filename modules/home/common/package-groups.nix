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
        delta
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
      ++ lib.optionals pkgs.stdenv.isLinux [ verible ]
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
      mesa-demos
      moonlight-qt
      mpv
      networkmanagerapplet
      nwg-displays
      pavucontrol
      playerctl
      pulseaudio
      qalculate-qt
      sioyek
      slurp
      sunshine
      swaynotificationcenter
      swayosd
      tailscale-systray
      tor-browser
      transmission_4-qt
      ttf-wps-fonts
      udiskie
      umu-launcher
      vulkan-tools
      waybar
      wayland-utils
      wayscriber
      winetricks
      wineWow64Packages.wayland
      wl-clip-persist
      wl-clipboard
      wlr-randr
      wttrbar
      xremap
      (pickNur "youtube_sync")
      (pickNur "riveroftime")
      (pickNur "gtk_applet")
      (pickNur "waybar_timer")
      (pickNur "nix-treemap")
      (pickNur "umu-fzf")
    ];

  desktop = headless ++ desktopAdditions;
  "headless-minimal" = minimal;
}
