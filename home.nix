{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./programs/firefox.nix
    ./programs/battery_monitor.nix
  ];

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "always";
  };
  programs.starship.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };
  programs.bash = {
    enable = true;
    initExtra = ''
      lfcd () {
          cd "$(command lf -print-last-dir "$@")"
      }
    '';
  };
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "dracula";
      theme_background = false; # use terminal background
      vim_keys = true;
      proc_tree = false;
      proc_sorting = "memory";
      update_ms = 1000;
    };
  };
  programs.bat = {
    enable = true;
    config = {theme = "Dracula";};
  };

  programs.fzf = {
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

  home.username = "emre";
  home.homeDirectory = "/home/emre";

  home.shellAliases = {
    ":q" = "exit";
    "hx." = "helix .";
    helix = "hx";
    lf = "lfcd";

    git = "git_clone_cached";
    "ga." = "git add .";
    ga = "git add";
    gd = "git diff";
    gp = "git push";
    gs = "git status";
    gc = "git commit";
    gcm = "git commit -m";
    gl = "git log";

    lutris = "nvidia-offload lutris";

    # ascp = "asusctl profile -p";
    # ascl = "asusctl profile -l";
    # ascsp = "asusctl profile -P Performance";
    # ascsb = "asusctl profile -P Balanced";
    # ascsq = "asusctl profile -P Quiet";

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

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 10;
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
    (nerdfonts.override {fonts = ["JetBrainsMono"];})
    ripgrep
    ripdrag
    tmux
    ffmpeg

    unar
    zip

    helix
    nixd
    alejandra
    ruff
    ruff-lsp
    nodePackages_latest.pyright
    rust-analyzer
    taplo
    nodePackages_latest.vscode-json-languageserver
    nodePackages_latest.bash-language-server
    nodePackages_latest.prettier
    clang-tools
    lldb
    cmake-language-server
    marksman
    gnumake
    texlab
    sioyek

    lutris
    udiskie
    # (pkgs.callPackage ./programs/wp.nix {})
    # (pkgs.callPackage ./programs/gtk_applet.nix {})
    (pkgs.callPackage ./programs/youtube_sync.nix {})
    # (pkgs.callPackage ./programs/clipboard_tts.nix {})
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

    DIRENV_WARN_TIMEOUT = "8m";

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

    MY_WALLPAPERS_DIR = "/mnt/second/images/art/wallpapers_pc";
    MY_GTASKS_OVERLAY_FILE = "/tmp/tasks_overlay.png";
    MY_ICS_OVERLAY_FILE = "/tmp/calendar_overlay.png";
    MY_FONT_FILE = "/mnt/second/fonts/anonymous.ttf";
    MY_PLAYLIST_FILE = "/mnt/second/playlists.txt";
    MY_MTD_OVERLAY_FILE = "/tmp/mtd_overlay.png";
    MY_OVERLAYED_FILE = "/tmp/overlayed.png";
    MY_ICS_FILE = "/tmp/calendar_events.ics";
    MY_MUSIC_DIR = "/mnt/second/music";
    MY_GTASKS_FILE = "/tmp/tasks.md";
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
