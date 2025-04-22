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
    (import ../common/xdg.nix {
      inherit pkgs inputs config;
      gdriveDir = "/home/${username}/Desktop/gdrive";
      dotfilesDir = "/home/${username}/Desktop/dotfiles";
    })
    ../common/sessionVariables.nix
    ../common/shellAliases.nix
  ];

  targets.genericLinux.enable = true;

  programs = {
    gpg.homedir = "${config.xdg.dataHome}/gnupg";
    home-manager.enable = true;
    starship.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };
    bash = {
      enable = true;
      # historyFile = # dont
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

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "24.05"; # do not change

    persistence."/persist/home" = {
      directories = [
        "Desktop"
        "Documents"
        "Downloads"
        "Videos"
        ".ssh"
        ".local/share/keyrings"
      ];
      allowOther = true;
    };
  };

  home.packages = with pkgs; [
    bandwhich
    vim
    yazi
    tree
    jq
    usbutils
    android-tools
    ripgrep
    tmux
    bat
    parallel-full
    trash-cli
    unar
    zip
    git
    fd
    fzf
    htop

    python3
    difftastic
    ffmpeg-full
    ghostscript
    # asm-lsp
    nixd
    nixfmt-rfc-style
    # ruff
    # ruff-lsp
    pyright
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
    gnumake
    yaml-language-server
    neovim
    helix
  ];
}
