{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./programs/firefox.nix
    ./programs/battery_monitor.nix
  ];

  programs.starship.enable = true;
  programs.direnv.enable = true;
  programs.bash = {
    enable = true;
    initExtra = ''
      lfcd () {
          cd "$(command lf -print-last-dir "$@")"
      }
    '';
  };

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
    # Not working
    # defaultOptions = [
    # "--bind 'tab:toggle-up,btab:toggle-down'"
    # ];
  };

  home.username = "emre";
  home.homeDirectory = "/home/emre";

  home.shellAliases = {
    ":q" = "exit";
    "hx." = "helix .";
    helix = "hx";
    lf = "lfcd";
    fzf = "fzf --bind 'tab:toggle-up,btab:toggle-down'";

    git = "git_clone_cached";
    ga = "git add";
    gd = "git diff";
    gp = "git push";
    gs = "git status";
    gc = "git commit";
    gl = "git log";

    lutris = "nvidia-offload lutris";

    ascp = "asusctl profile -p";
    ascl = "asusctl profile -l";
    ascsp = "asusctl profile -P Performance";
    ascsb = "asusctl profile -P Balanced";
    ascsq = "asusctl profile -P Quiet";

    tmux = "tmux -f ~/.config/tmux/tmux.conf";
    txa = "tmux attach-session -t";
    txls = "tmux list-sessions";
    txks = "tmux kill-session -t ";
    txn = "tmux new-session -s";
    txs = "tmux switch-client -n";
    txkw = "tmux kill-window -t ";
    txlw = "tmux list-windows";
    txh = ''tmux new-session -s "$(basename "$(pwd)")_$(echo -n "$(pwd)" | md5sum | cut -d " " -f 1)" "hx ."'';

    wget = ''wget --hsts-file="$XDG_DATA_HOME/wget-hsts"'';
    arduino-cli = "arduino-cli --config-file $XDG_CONFIG_HOME/arduino15/arduino-cli.yaml";
  };

  home.stateVersion = "23.05"; # You should not change this value.

  gtk = {
    enable = true;
    theme = {
      package = pkgs.dracula-theme;
      name = "Dracula";
    };
    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  home.packages = with pkgs; [
    python3

    jq # to parse hyprctl
    usbutils
    pavucontrol
    android-file-transfer
    yarr
    transmission
    libsForQt5.kolourpaint
    libsForQt5.breeze-icons
    # etcher # BUG electron not safe
    nwg-displays
    hyprshot
    networkmanagerapplet
    brightnessctl
    kooha
    transmission
    swaynotificationcenter

    playerctl
    swww
    mpv
    btop
    (nerdfonts.override {fonts = ["JetBrainsMono"];})
    bat
    ripgrep
    ripdrag
    tmux
    ffmpeg

    helix
    nixd
    alejandra
    ruff
    ruff-lsp
    nodePackages_latest.pyright
    rust-analyzer
    taplo
    texlab
    sioyek

    lutris

    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
    gparted
  ];

  home.sessionVariables = {
    OPENER = "xdg-open";
    EDITOR = "helix";
    TERMINAL = "kitty";
    TERM = "kitty";

    PROMPT_COMMAND = "history -a";

    # export PATH="$XDG_DATA_HOME:$XDG_CONFIG_HOME:$XDG_STATE_HOME:$XDG_CACHE_HOME:$PATH"
    # env = PATH,$HOME/.local/bin:$PATH
    # env = PATH,/usr/local/bin:$PATH

    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_STATE_HOME = "$HOME/.local/state";
    XDG_CACHE_HOME = "$HOME/.cache";

    DIRENV_WARN_TIMEOUT = 0;

    DIRENV_CONFIG = "$HOME/.config/direnv/direnvrc";
    ANDROID_HOME = "$XDG_DATA_HOME/android";
    CARGO_HOME = "$XDG_DATA_HOME/cargo";
    CUDA_CACHE_PATH = "$XDG_CACHE_HOME/nv";
    GNUPGHOME = "$XDG_DATA_HOME/gnupg"; # handled in home manager
    PASSWORD_STORE_DIR = "$XDG_DATA_HOME/password-store";
    RUSTUP_HOME = "$XDG_DATA_HOME/rustup";
    NUGET_PACKAGES = "$XDG_CACHE_HOME/NuGetPackages";
    NPM_CONFIG_USERCONFIG = "$XDG_CONFIG_HOME/npm/npmrc";
    DOTNET_CLI_HOME = "/tmp/DOTNET_CLI_HOME";
    WGETRC = "$XDG_CONFIG_HOME/wgetrc";
    KIVY_HOME = "$XDG_CONFIG_HOME/kivy";
    PYTHONPYCACHEPREFIX = "$XDG_CACHE_HOME/python";
    PYTHONUSERBASE = "$XDG_DATA_HOME/python";
    GOPATH = "$XDG_CACHE_HOME/go";
    # GTK2_RC_FILES = "$XDG_CONFIG_HOME/gtk-2.0/gtkrc"; # handled in home manager
    GTK_RC_FILES = "$XDG_CONFIG_HOME/gtk-1.0/gtkrc";
    VIMINIT = ''set nocp | source ''${XDG_CONFIG_HOME:-$HOME/.config}/vim/vimrc'';
  };

  programs.gpg.homedir = "${config.xdg.dataHome}/gnupg";
  # xdg.configFile.foo.source =  config.lib.file.mkOutOfStoreSymlink "/absolute/path/to/bar";

  xdg = {
    configFile."." = {
      source = ./.config;
      recursive = true;
    };
    # TODO : chmod x all bins
    dataFile."." = {
      source = ./.local/share;
      recursive = true;
    };
  };
  home.file.".local/bin" = {
    source = ./.local/bin;
    recursive = true;
    executable = true;
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
