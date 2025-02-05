{
  pkgs,
  config,
  inputs,
  userSettings,
  ...
}:
{
  imports = [
    ../../system/app/firefox.nix
    ../../system/app/thunderbird.nix
    ../../system/app/low_battery_notify.nix
    ../../system/app/xdg.nix
  ];

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };

  targets.genericLinux.enable = true;

  programs = {
    gpg.homedir = "${config.xdg.dataHome}/gnupg";
    home-manager.enable = true; # Let Home Manager install and manage itself.
    starship.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };
    bash = {
      enable = true;
      historyFile = "${config.home.sessionVariables.XDG_STATE_HOME}/bash/history";
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
  services.udiskie.enable = true;
  # https://github.com/nix-community/home-manager/issues/2064
  systemd.user.targets.tray.Unit.Requires = [ "graphical-session.target" ];

  # https://github.com/hyprwm/hyprpicker/issues/51#issuecomment-2016368757

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
    platformTheme.name = "gtk";
  };
  # # requires hardware.uinput.enable = true;

  # Inconsistent launch on boot
  # services.xremap = {
  #   enable = true;
  #   withWlroots = true;
  #   watch = true;
  #   # username = userSettings.username;
  #   yamlConfig = builtins.readFile ../../.config/xremap/config.yml;
  # };

  # https://github.com/NixOS/nixpkgs/issues/333123
  # services.ollama = {
  #   package = pkgs.ollama-cuda;
  #   enable = true;
  #   # openFirewall = true;
  #   # host = "0.0.0.0";
  #   # port = 11434;
  #   # models = "/tmp";
  #   acceleration = "cuda";

  #   environmentVariables = {
  #     HSA_OVERRIDE_GFX_VERSION = "10.1.0";
  #     CUDA_VISIBLE_DEVICES = "1";
  #     LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudatoolkit}/lib64";
  #   };
  # };

  home = rec {
    inherit (userSettings) username;
    homeDirectory = "/home/${username}";

    stateVersion = "24.05"; # do not change

    pointerCursor = {
      gtk.enable = true;
      name = "Dracula-cursors";
      package = pkgs.dracula-theme;
      size = 10;
    };

  };

  home.shellAliases = {
    ":q" = "exit";
    "q:" = "exit";
    ":wq" = "exit";
    "hx." = "helix .";
    ".." = "cd ..";
    "c" = "clear";
    "cd.." = "cd ..";
    helix = "hx";
    lf = ''echo "Did you mean f?"''; # muscle memory
    # f = "lf_cd";
    f = "yazi_cd";
    ff = "yazi_cd";
    cdf = ''cd "$(find . -type d | fzf)"'';
    da = "direnv allow";
    # tt = ''tt --window_state=list'';
    # tl = ''task list'';

    git = "git_cached";
    "ga." = "git add .";
    ga = "git add";
    gd = "git -c diff.external=difft diff";
    gdc = "git -c diff.external=difft diff --cached";
    gp = "git push";
    gpf = "git push --force";
    gr = "git restore";
    "gr." = "git restore .";
    grs = "git restore --staged";
    gs = "git status";
    gb = "fzf_git_branches";
    gc = "git commit";
    gcm = "git commit -m ";
    gca = "git commit --amend";
    gl = "fzf_git_commits";

    # ascp = "asusctl profile -p";
    # ascl = "asusctl profile -l";
    # ascsp = "asusctl profile -P Performance";
    # ascsb = "asusctl profile -P Balanced";
    # ascsq = "asusctl profile -P Quiet";
    yarn = ''yarn --use-yarnrc "$XDG_CONFIG_HOME/yarn/config"'';

    tmux = "tmux -f ~/.config/tmux/tmux.conf";
    txa = ''tmux attach-session -t $(tmux list-sessions -F "#{session_name}" | head -n 1)'';
    txls = "tmux list-sessions";
    txks = "tmux kill-session -t ";
    txn = "tmux new-session -s";
    txs = "tmux switch-client -n";
    txkw = "tmux kill-window -t ";
    txlw = "tmux list-windows";
    # txh = ''tmux new-session -s "$(basename "$(pwd)")_$(echo -n "$(pwd)" | md5sum | cut -d " " -f 1)" "hx ."'';

    wget = ''wget --hsts-file="$XDG_DATA_HOME/wget-hsts"'';
    arduino-cli = "arduino-cli --config-file $XDG_CONFIG_HOME/arduino15/arduino-cli.yaml";

    # llama = ''nix run git+https://github.com/nixified-ai/flake.git#textgen-nvidia'';

    fan-turbo = ''cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 1 >>  fan_boost_mode"; sudo sh -c "echo 1 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'';
    fan-performance = ''cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 0 >>  fan_boost_mode"; sudo sh -c "echo 0 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'';
    fan-silent = ''cd /sys/devices/platform/asus-nb-wmi; sudo sh -c "echo 2 >>  fan_boost_mode"; sudo sh -c "echo 2 >> throttle_thermal_policy"; source ~/.bashrc; cd ~;'';
  };

  home.packages = with pkgs; [
    # awatcher
    # aw-watcher-afk
    # aw-watcher-window
    # aw-server-rust
    # (pkgs.callPackage ../../system/app/aw-manager.nix { })
    # (pkgs.callPackage ../../system/app/aw-watchers-mine.nix { })

    # (pkgs.callPackage ../../system/app/prometheus-exporters.nix { })
    #
    (pkgs.callPackage ../../system/app/quantifyself.nix { })
    (pkgs.callPackage ../../system/app/quantifyself-webui.nix { })

    (pkgs.callPackage ../../system/app/html-preview-lsp.nix { })
    (pkgs.callPackage ../../system/app/html-preview-server.nix { })

    bandwhich # network monitoring TUI
    cpufrequtils
    hypridle
    vim # default editor
    waybar
    hyprlock
    xwaylandvideobridge
    tor-browser
    qalculate-qt
    libqalculate
    # (lf.overrideAttrs (oldAttrs: {
    #   patches = oldAttrs.patches or [] ++ [../../system/app/lf.patch];
    # }))
    yazi
    wl-clipboard
    wl-clip-persist
    pulseaudio
    tree
    anki-bin
    piper-tts

    python3

    difftastic
    jq # to parse hyprctl
    usbutils
    pavucontrol
    android-tools # adb
    transmission_4-qt
    libsForQt5.kolourpaint
    libsForQt5.qt5.qtimageformats # webp support for kolourpaint
    libsForQt5.breeze-icons
    ventoy
    nwg-displays
    wlr-randr # nwg-displays dependency
    hyprshot
    networkmanagerapplet
    brightnessctl
    kooha
    swaynotificationcenter

    playerctl
    swww # for update_wp
    activate-linux # for update_wp
    mpv
    # (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    # nerd-fonts.jetbrains-mono
    ripgrep
    # ripdrag # started to fail when nvidia gpu is enabled
    xdragon
    tmux
    ffmpeg-full
    ffmpegthumbnailer # for yazi opus plugin
    bat
    libnotify
    parallel-full

    imhex
    trash-cli
    unar
    zip
    ghostscript
    drawio

    rclone
    # citrix_workspace
    # helix
    # helix-gpt
    # (koboldcpp.override { cublasSupport = true; })
    # (pkgs.llama-cpp.override { cudaSupport = true; })
    ollama-cuda
    lsp-ai
    asm-lsp
    nixd
    # alejandra
    nixfmt-rfc-style
    ruff
    ruff-lsp
    pyright
    # rustup component add rust-analyzer
    rust-analyzer
    rustfmt
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
    # markdown-oxide
    gnumake
    (pkgs.callPackage ../../system/app/texlab.nix { })
    sioyek
    yaml-language-server
    verible
    nodePackages.diagnostic-languageserver
    verilator

    lua-language-server
    # vale-ls
    # typos-lsp
    # ltex-ls

    neovim
    # taskwarrior
    # timewarrior

    adb-sync
    wineWowPackages.waylandFull
    winetricks
    steam-run # quick runner for fsh compliant binaries
    udiskie
    # (pkgs.callPackage ../../system/app/tt.nix {})
    # (pkgs.callPackage ../../system/app/j4-dmenu-desktop.nix { })
    (pkgs.callPackage ../../system/app/waybar_timer.nix { })
    (pkgs.callPackage ../../system/app/xremap.nix { })

    (pkgs.callPackage ../../system/app/helix.nix { })
    (pkgs.callPackage ../../system/app/mitype.nix { })
    # (pkgs.callPackage ../../system/app/rvc-cli.nix { })
    (pkgs.callPackage ../../system/app/gen_typing_test.nix { })
    (pkgs.callPackage ../../system/app/print_weather.nix { })
    (pkgs.callPackage ../../system/app/notify_scheduler.nix { })
    # (pkgs.callPackage ../../system/app/blender.nix { })

    (pkgs.callPackage ../../system/app/veridian.nix { })
    # (pkgs.callPackage ../../system/app/veridian.nix { withSlang = true; })
    (pkgs.callPackage ../../system/app/update_wp.nix { })
    (pkgs.callPackage ../../system/app/gtk_applet.nix { })
    (pkgs.callPackage ../../system/app/gtk_indicator.nix { })
    # (pkgs.callPackage ../../system/app/svlangserver.nix {})
    (pkgs.callPackage ../../system/app/youtube_sync.nix { })
    (pkgs.callPackage ../../system/app/auto_refresh.nix { })
    (pkgs.callPackage ../../system/app/clipboard_tts.nix { })
  ];

  home.sessionVariables = {
    OPENER = "xdg-open";
    EDITOR = "hx";
    TERMINAL = "kitty";
    TERM = "kitty";

    GTK_THEME = "Dracula"; # config.gtk.theme.name;

    # export PATH="${config.home.sessionVariables.XDG_DATA_HOME}:${XDG_CONFIG_HOME}:$XDG_STATE_HOME:$XDG_CACHE_HOME:$PATH"
    # env = PATH,$HOME/.local/bin:$PATH
    # env = PATH,/usr/local/bin:$PATH

    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_STATE_HOME = "$HOME/.local/state";
    XDG_CACHE_HOME = "$HOME/.cache";

    DIRENV_WARN_TIMEOUT = "8m";

    # WARNING: DO NOT SET DIRENV_CONFIG
    # DIRENV_CONFIG = "${config.home.sessionVariables.XDG_CONFIG_HOME}/direnv/direnvrc";
    WINEPREFIX = "${config.home.sessionVariables.XDG_DATA_HOME}/wine"; # special case
    ANDROID_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/android";
    CARGO_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/cargo";
    CUDA_CACHE_PATH = "${config.home.sessionVariables.XDG_CACHE_HOME}/nv";
    GNUPGHOME = "${config.home.sessionVariables.XDG_DATA_HOME}/gnupg"; # handled in home manager
    PASSWORD_STORE_DIR = "${config.home.sessionVariables.XDG_DATA_HOME}/password-store";
    RUSTUP_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/rustup";
    NUGET_PACKAGES = "${config.home.sessionVariables.XDG_CACHE_HOME}/NuGetPackages";
    NPM_CONFIG_USERCONFIG = "${config.home.sessionVariables.XDG_CONFIG_HOME}/npm/npmrc";
    DOTNET_CLI_HOME = "/tmp/DOTNET_CLI_HOME";
    WGETRC = "${config.home.sessionVariables.XDG_CONFIG_HOME}/wgetrc";
    KIVY_HOME = "${config.home.sessionVariables.XDG_CONFIG_HOME}/kivy";
    PYTHONPYCACHEPREFIX = "${config.home.sessionVariables.XDG_CACHE_HOME}/python";
    PYTHONUSERBASE = "${config.home.sessionVariables.XDG_DATA_HOME}/python";
    PYTHON_HISTORY = "${config.home.sessionVariables.XDG_STATE_HOME}/python/history";
    PYTHONSTARTUP = "${config.home.sessionVariables.XDG_STATE_HOME}/python/pythonrc";
    GOPATH = "${config.home.sessionVariables.XDG_CACHE_HOME}/go";
    PARALLEL_HOME = "${config.home.sessionVariables.XDG_CONFIG_HOME}/parallel";
    MYSQL_HISTFILE = "${config.home.sessionVariables.XDG_DATA_HOME}/mysql_history";
    SQLITE_HISTORY = "${config.home.sessionVariables.XDG_CACHE_HOME}/sqlite_history";
    DUCKDB_HISTORY = "${config.home.sessionVariables.XDG_CACHE_HOME}/duckdb_history";
    GRIPHOME = "${config.home.sessionVariables.XDG_CONFIG_HOME}/grip";
    GDBHISTFILE = "${config.home.sessionVariables.XDG_STATE_HOME}/gdb/history";
    # _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=$${XDG_CONFIG_HOME}}/java"; # not working
    KERAS_HOME = "${config.home.sessionVariables.XDG_STATE_HOME}/keras";
    # GTK2_RC_FILES = "${XDG_CONFIG_HOME}/gtk-2.0/gtkrc"; # handled in home manager
    GTK_RC_FILES = "${config.home.sessionVariables.XDG_CONFIG_HOME}/gtk-1.0/gtkrc";
    # Breaks neovim
    # VIMINIT = ''set nocp | source ''$${XDG_CONFIG_HOME}:-$HOME/.config}/vim/vimrc'';
    TEXMFHOME = "${config.home.sessionVariables.XDG_DATA_HOME}/texmf";
    TEXMFVAR = "${config.home.sessionVariables.XDG_CACHE_HOME}/texlive/texmf-var";
    TEXMFCONFIG = "${config.home.sessionVariables.XDG_CONFIG_HOME}/texlive/texmf-config";

    OLLAMA_MODELS = "${config.home.sessionVariables.XDG_DATA_HOME}/ollama/models";
    LEIN_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/lein";

    LM_LICENSE_FILE = "${config.home.sessionVariables.XDG_CONFIG_HOME}/mylib/questa_license.dat";

    PDK_ROOT = "${config.home.sessionVariables.XDG_DATA_HOME}/pdk";

    IGNOREEOF = "4";
    # needed by termfilechooser portal, # not working
    # TERMCMD = "${pkgs.kitty}/bin/kitty --class=file_chooser --override background_opacity=1";
  };

}
