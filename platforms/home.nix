{
  pkgs,
  username,
  config,
  inputs,
  ...
}: {
  imports = [
    ../programs/firefox.nix
    ../programs/low_battery_notify.nix
    ../programs/xdg.nix

    inputs.xremap-flake.homeManagerModules.default
  ];

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  targets.genericLinux.enable = true;

  programs.starship.enable = true;
  services.udiskie.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };
  programs.bash = {
    enable = true;
    # https://github.com/nix-community/home-manager/issues/183
    sessionVariables = {
      EDITOR = "hx";
    };

    historySize = 10000000;
    historyFileSize = 10000000;
    historyControl = ["erasedups" "ignoredups" "ignorespace"];
    enableCompletion = true;
    bashrcExtra = ''
      PROMPT_COMMAND="history -a; history -r"
    '';
    initExtra = ''
      lfcd () {
          cd "$(command lf -print-last-dir "$@")"
      }
    '';
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

  gtk = {
    enable = true;
    theme = {
      package = pkgs.dracula-theme;
      name = "Dracula";
    };
    iconTheme = {
      package = pkgs.dracula-icon-theme;
      name = "Dracula";
    };
    cursorTheme = {
      name = "Dracula-cursors";
      package = pkgs.dracula-theme;
      size = 10;
    };
    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
  qt = {
    enable = true;
    #useGtkTheme = true;
    platformTheme = "gtk";
  };
  # # requires hardware.uinput.enable = true;
  services.xremap = {
    withWlroots = true;
    # userName = "emre";
    yamlConfig = builtins.readFile ../.config/xremap/config.yml;
  };

  home = {
    homeDirectory = "/home/${username}";
    username = "${username}";
    stateVersion = "23.05"; # do not change
  };

  home.shellAliases = {
    ":q" = "exit";
    "hx." = "helix .";
    helix = "hx";
    lf = ""; # muscle memory
    f = "lfcd";
    cdf = ''cd "$(find . -type d | fzf)"'';
    # tt = ''tt --window_state=list'';
    # tl = ''task list'';

    git = "git_cached";
    "ga." = "git add .";
    ga = "git add";
    gd = "git diff";
    gp = "git push";
    gs = "git status";
    gc = "git commit";
    gcm = "git commit -m";
    gl = "git log";

    # ascp = "asusctl profile -p";
    # ascl = "asusctl profile -l";
    # ascsp = "asusctl profile -P Performance";
    # ascsb = "asusctl profile -P Balanced";
    # ascsq = "asusctl profile -P Quiet";
    yarn = ''yarn --use-yarnrc "$XDG_CONFIG_HOME/yarn/config"'';

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

    llama = ''nix run git+https://github.com/nixified-ai/flake.git#textgen-nvidia'';
    tor = ''nix run nixpkgs#tor-browser'';
  };
  home.packages = with pkgs; [
    cpufrequtils
    swaylock
    vim # default editor
    waybar
    kitty
    wofi
    firefox
    (lf.overrideAttrs (oldAttrs: {
      patches = oldAttrs.patches or [] ++ [../programs/lf.patch];
    }))
    wl-clipboard
    wl-clip-persist
    pulseaudio

    python3

    jq # to parse hyprctl
    usbutils
    pavucontrol
    android-file-transfer
    transmission-qt
    libsForQt5.kolourpaint
    libsForQt5.breeze-icons
    # etcher # BUG electron not safe
    nwg-displays
    wlr-randr # nwg-displays dependency
    hyprshot
    networkmanagerapplet
    brightnessctl
    kooha
    swaynotificationcenter

    playerctl
    swww
    mpv
    (nerdfonts.override {fonts = ["JetBrainsMono"];})
    ripgrep
    ripdrag
    tmux
    ffmpeg
    bat
    btop
    libnotify

    trash-cli
    unar
    zip
    ghostscript

    helix
    nixd
    alejandra
    ruff
    ruff-lsp
    nodePackages_latest.pyright
    # rustup component add rust-analyzer
    rust-analyzer
    clippy
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
    yaml-language-server
    verible
    nodePackages.diagnostic-languageserver
    verilator

    # I would put this in shell.nix however I cant let it get garbage collected
    (quartus-prime-lite.override {
      supportedDevices = ["Cyclone V"];
    })

    # taskwarrior
    # timewarrior

    bottles
    udiskie
    # (pkgs.callPackage ../programs/tt.nix {})
    (pkgs.callPackage ../programs/wttr.nix {})
    (pkgs.callPackage ../programs/blender.nix {})
    (pkgs.callPackage ../programs/veridian.nix {})
    (pkgs.callPackage ../programs/update_wp.nix {})
    (pkgs.callPackage ../programs/gtk_applet.nix {})
    (pkgs.callPackage ../programs/svlangserver.nix {})
    (pkgs.callPackage ../programs/youtube_sync.nix {})
    (pkgs.callPackage ../programs/auto_refresh.nix {})
    # (pkgs.callPackage ./programs/clipboard_tts.nix {})
  ];

  home.sessionVariables = {
    OPENER = "xdg-open";
    EDITOR = "hx";
    TERMINAL = "kitty";
    TERM = "kitty";

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
    WINEPREFIX = "$XDG_DATA_HOME/wineprefixes/default";
    _JAVA_OPTIONS = ''-Djava.util.prefs.userRoot="$XDG_CONFIG_HOME"/java'';
    # GTK2_RC_FILES = "$XDG_CONFIG_HOME/gtk-2.0/gtkrc"; # handled in home manager
    GTK_RC_FILES = "$XDG_CONFIG_HOME/gtk-1.0/gtkrc";
    VIMINIT = ''set nocp | source ''${XDG_CONFIG_HOME:-$HOME/.config}/vim/vimrc'';

    LM_LICENSE_FILE = "$HOME/.config/mylib/questa_license.dat";

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

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
