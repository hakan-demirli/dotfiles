{
  config,
  pkgs,
  ...
}: {
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "emre";
  home.homeDirectory = "/home/emre";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.firefox
    pkgs.waybar
    # pkgs.networkmanagerapplet
    # pkgs.blueman
    # pkgs.swaynotificationcenter
    pkgs.hyprshot
    # pkgs.swww
    # pkgs.nwg-displays
    pkgs.swaylock
    # pkgs.etcher
    pkgs.usbutils
    # pkgs.ffmpeg
    # pkgs.libsForQt5.kolourpaint
    pkgs.wofi
    pkgs.lf
    # pkgs.mpv
    pkgs.ripdrag
    # pkgs.transmission
    pkgs.dracula-theme

    pkgs.helix
    pkgs.ruff
    pkgs.ruff-lsp
    pkgs.nodePackages_latest.pyright
    pkgs.taplo
    pkgs.fzf
    pkgs.bat
    pkgs.tmux
    pkgs.texlab
    # pkgs.sioyek
    pkgs.nixd
    pkgs.alejandra
    pkgs.direnv
    pkgs.starship
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/emre/etc/profile.d/hm-session-vars.sh
  #
  wayland.windowManager.hyprland.enable = true;

  home.file."${config.xdg.configHome}" = {
    source = ../.config;
    recursive = true;
  };

  home.sessionVariables = {
    # EDITOR = "emacs";
    PATH = "home/emre/.local/state/nix/profile/bin:$PATH";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
