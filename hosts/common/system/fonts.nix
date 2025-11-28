{
  pkgs,
  minimalFonts ? throw "You must specify a font type",
  ...
}:

let
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
  fonts = {
    fontDir = {
      enable = true;
      decompressFonts = true;
    };

    packages = if minimalFonts then minimal-packages else (minimal-packages ++ desktop-packages);

    fontconfig = {
      enable = true;
      defaultFonts =
        if minimalFonts then { monospace = [ "JetBrainsMono Nerd Font" ]; } else desktop-config;
    };
  };
}
