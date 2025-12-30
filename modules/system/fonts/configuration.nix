{
  flake.modules.nixos.system-fonts = { config, pkgs, lib, ... }:
  let
    cfg = config.system.fonts;
    minimal-packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      powerline-fonts
    ];

    desktop-packages = with pkgs; [
      (callPackage ../../../pkgs/ms-fonts.nix { })
      corefonts
      lato
      dejavu_fonts
      material-icons
      material-symbols
      material-design-icons
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      roboto
      vista-fonts
      poppins
    ];

    desktop-config = {
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Color Emoji"
      ];
      sansSerif = [
        "Noto Sans"
        "Noto Color Emoji"
      ];
      serif = [
        "Noto Serif"
        "Noto Color Emoji"
      ];
      emoji = [ "Noto Color Emoji" ];
    };
  in
  {
    options.system.fonts.minimal = lib.mkEnableOption "minimal fonts";

    config = {
      fonts = {
        fontDir = {
          enable = true;
          decompressFonts = true;
        };

        packages = if cfg.minimal then minimal-packages else (minimal-packages ++ desktop-packages);

        fontconfig = {
          enable = true;
          defaultFonts =
            if cfg.minimal then { monospace = [ "JetBrainsMono Nerd Font" ]; } else desktop-config;
        };
      };
    };
  };
}
