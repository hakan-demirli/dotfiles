{
  pkgs,
  lib,
  facts,
  inputs,
  ...
}:
let
  nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };
  pickNur = name: nurPkgs.${name} or null;

  dev-essentials = with pkgs; [
    bat
    btop
    delta
    eza
    fd
    fzf
    gh
    git
    htop
    jq
    parallel-full
    ripgrep
    starship
    tealdeer
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
      (pickNur "dap")
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
      aider-chat
      claude-code
    ]
    ++ lib.optional (pickNur "raider" != null) (pickNur "raider");
in
{
  nixpkgs.overlays = [
    (import ./pkgs/nix/overlay.nix {
      hasNvidia = facts.hasNvidia or false;
    })
  ];

  home.packages = dev-essentials ++ editors ++ lsp ++ tools-cli ++ server-cli ++ ai;

  programs = {
    bash = {
      enable = true;
      historyFile = "$HOME/.local/state/bash/history";
      historyFileSize = -1;
      historySize = -1;
      historyControl = [
        "ignoredups"
        "ignorespace"
        "erasedups"
      ];
      shellOptions = [
        "histappend"
        "checkwinsize"
        "extglob"
        "globstar"
        "checkjobs"
        "autocd"
      ];
      bashrcExtra = ''
        export LESS='-R --use-color -Dd+r$Du+b'
        PROMPT_COMMAND="history -a; history -n"
      '';
      initExtra = ''
        if [ -f "$HOME/.config/bash/main.sh" ]; then
          # shellcheck source=/dev/null
          source "$HOME/.config/bash/main.sh"
        fi
      '';
    };

    fzf.enable = true;
    zoxide.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    starship = {
      enable = true;
      enableBashIntegration = true;
    };
  };

  home.activation = {
    bashHistoryDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.local/state/bash"
    '';
    factsAvailable = ''
      echo "infra-home activating for ${facts.id} (cluster=${toString facts.cluster}, roles=[${pkgs.lib.concatStringsSep "," facts.roles}])"
    '';
  };
}
