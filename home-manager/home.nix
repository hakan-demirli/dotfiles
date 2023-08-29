# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)

{ inputs, lib, config, pkgs, ... }: {
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
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
      neovim
      firefox
      vscode
      kitty
      drawing
      sayonara
      wofi
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
    ];
    sessionVariables = {
      EDITOR = "code";
      BROWSER = "firefox";
      TERMINAL = "kitty";
      TERM = "kitty";
    };
  };


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

  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
