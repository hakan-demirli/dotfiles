{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./programs/firefox.nix
  ];

  programs.direnv.enable = true;
  programs.bash.enable = true;
  programs.starship.enable = true;

  programs.fzf.enable = true;
  programs.fzf.enableBashIntegration = true;

  home.username = "emre";
  home.homeDirectory = "/home/emre";

  home.shellAliases = {
    ":q" = "exit";
    lf = "lfcd";
    git = "git_clone_cached";
    ga = "git add";
    gd = "git diff";
    gp = "git push";
    gs = "git status";
    gc = "git commit";
    gl = "git log";

    ascp = "asusctl profile -p";
    ascl = "asusctl profile -l";
    ascsp = "asusctl profile -P Performance";
    ascsb = "asusctl profile -P Balanced";
    ascsq = "asusctl profile -P Quiet";
  };

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  gtk = {
    enable = true;
    theme = {
      package = pkgs.dracula-theme;
      name = "Dracula";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  services.swayosd.enable = true;
  #  services.udisks2.enable = true;
  #  programs.gnome-disks.enable = true;
  home.packages = with pkgs; [
    python3

    networkmanagerapplet
    brightnessctl
    kooha
    transmission
    swaynotificationcenter
    # swayosd
    playerctl
    swww
    mpv
    btop
    (nerdfonts.override {fonts = ["JetBrainsMono"];})
    bat
    ripgrep
    tmux

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

    DIRENV_CONFIG = "$HOME/.config/direnv/direnvrc";
    ANDROID_HOME = "$XDG_DATA_HOME/android";
    CARGO_HOME = "$XDG_DATA_HOME/cargo";
    CUDA_CACHE_PATH = "$XDG_CACHE_HOME/nv";
    GNUPGHOME = "$XDG_DATA_HOME/gnupg";
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
  };

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

  # home.file."${config.xdg.configHome}" = {
  #   source = ./.config;
  #   recursive = true;
  # };
  # home.file."${config.xdg.dataHome}" = {
  #   source = ./.local;
  #   recursive = true;
  # };

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  # home.file = {
  # # Building this configuration will create a copy of 'dotfiles/screenrc' in
  # # the Nix store. Activating the configuration will then make '~/.screenrc' a
  # # symlink to the Nix store copy.
  # ".screenrc".source = dotfiles/screenrc;

  # # You can also set the file content immediately.
  # ".gradle/gradle.properties".text = ''
  #   org.gradle.console=verbose
  #   org.gradle.daemon.idletimeout=3600000
  # '';
  # };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/emre/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
