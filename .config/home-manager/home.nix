{ config, pkgs, ... }:

{
  imports = [
    # ./nvim.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # If you want to use overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    username = "emre";
    homeDirectory = "/home/emre";
    packages = with pkgs; [
      git
      kitty
      wofi
      neovim
      firefox
      vscode
      drawing
      sayonara
      waybar
      yt-dlp-light
      ffmpeg
      virt-manager
      dconf
      asusctl
      python310
      gnome.gnome-control-center
      gnome.gnome-system-monitor
      gnome.gnome-disk-utility
      cinnamon.nemo-with-extensions
      nixpkgs-fmt # for nix-ide extension on vscode
      pciutils # for lspci command
      (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
      (lutris.override {
        extraLibraries = pkgs: [
          # List library dependencies here
        ];
        extraPkgs = pkgs: [
          # List package dependencies here
        ];
      })
      # # You can also create simple shell scripts directly inside your
      # # configuration. For example, this adds a command 'my-hello' to your
      # # environment:
      # (pkgs.writeShellScriptBin "my-hello" ''
      #   echo "Hello, ${config.home.username}!"
      # '')
    ];
    sessionVariables = {
      EDITOR = "nvim";
      BROWSER = "firefox";
      TERMINAL = "kitty";
      TERM = "kitty";
    };
    stateVersion = "23.05"; # Dont change this.
  };


  # https://github.com/nix-community/home-manager/issues/2085
  # home.file.".gitconfig".source = config.lib.file.mkOutOfStoreSymlink ../git/.gitconfig;
  xdg.configFile."nvim" = {
    recursive = true;
    source = config.lib.file.mkOutOfStoreSymlink ../nvim;
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
  dconf.settings = {
    # for virt-manager
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
    "org/gnome/desktop/default-applications/terminal" = {
      exec = "kitty";
    };
    "org/cinnamon/desktop/applications/terminal" = {
      exec = "kitty";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
