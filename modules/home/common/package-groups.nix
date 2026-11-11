{
  inputs,
  lib,
  pkgs,
}:
let
  nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };
  pickNur = name: nurPkgs.${name} or null;
  unstablePkgs = (import ./lib.nix).mkUnstablePkgs { inherit inputs pkgs; };
  claudeMulti = lib.mapNullable (package: package.override { inherit (unstablePkgs) claude-code; }) (
    pickNur "opencode-plugins"
  );
  sendToLaptop = pkgs.callPackage ./pkgs/nix/send-to-laptop.nix { };

  helixWithEditorTools = pkgs.symlinkJoin {
    name = "helix-with-editor-tools-${lib.getVersion pkgs.helix}";
    paths = [ pkgs.helix ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hx --suffix PATH : ${lib.makeBinPath (import ./editor-tools.nix pkgs)}
    '';
  };

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
        bat
        unstablePkgs.claude-code
        claudeMulti
        fd
        ffmpeg-full
        file
        gnumake
        helixWithEditorTools
        nixfmt
        openssl
        ouch
        parallel-full
        ripgrep
        sendToLaptop
        shfmt
        trash-cli
        tree
        verilator
        wget
        yek
        zip
        (pickNur "uncomment")
        (pickNur "flake-updater")
      ]
      ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ verible ]
    );

  development = minimal ++ developmentAdditions;

  headlessAdditions = with pkgs; [ lazygit ];
  headless = development ++ headlessAdditions;

  desktopAdditions =
    with pkgs;
    lib.filter (package: package != null) [
      better-adb-sync
      android-tools
      autoRefresh
      awww
      brightnessctl
      dragon-drop
      drawio
      exfatprogs
      gamescope
      grim
      hypridle
      hyprlock
      kdePackages.breeze-icons
      kdePackages.kolourpaint
      kdePackages.qtimageformats
      libnotify
      libqalculate-fzf
      localsend
      mangohud
      material-symbols
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
      wayscriber
      winetricks
      wineWow64Packages.wayland
      wl-clipboard
      wttrbar
      xdg-terminal-exec
      xremap
      xwayland-satellite
      (pickNur "youtube-sync")
      (pickNur "gtk-applet")
      (pickNur "umu-fzf")
    ];

  desktop = headless ++ desktopAdditions;
  "headless-minimal" = minimal;
}
