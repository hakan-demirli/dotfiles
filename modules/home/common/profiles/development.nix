{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };
  pickNur = name: nurPkgs.${name} or null;
  sendToLaptop = pkgs.callPackage ../pkgs/nix/send-to-laptop.nix { };

  dev-essentials = with pkgs; [
    bat
    btop
    delta
    fd
    fzf
    git
    htop
    jq
    parallel-full
    ripgrep
    starship
    tmux
    trash-cli
    tree
    yazi
    yek
  ];

  editors = with pkgs; [
    helix
    vim
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
      lldb
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
      verilator
      vscode-langservers-extracted
      yaml-language-server
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      verible
    ];

  tools-cli =
    with pkgs;
    lib.filter (x: x != null) [
      curl
      ffmpeg-full
      ffmpegthumbnailer
      file
      ghostscript
      openssl
      ouch
      p7zip
      rsync
      unzip
      wget
      zip
      sendToLaptop
      (pickNur "uncomment")
      (pickNur "flake-updater")
    ];

  server-cli =
    with pkgs;
    [
      bandwhich
      systemctl-tui
      usbutils
    ]
    ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 cpufrequtils;

  ai =
    with pkgs;
    [
      aichat
      claude-code
    ]
    ++ lib.optional (pickNur "raider" != null) (pickNur "raider");
in
{
  home.packages = dev-essentials ++ editors ++ lsp ++ tools-cli ++ server-cli ++ ai;

  programs = {
    gh = {
      enable = true;
      gitCredentialHelper.enable = false;
      settings.git_protocol = "https";
    };

    fzf.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    starship = {
      enable = true;
      enableBashIntegration = true;
    };
  };
}
