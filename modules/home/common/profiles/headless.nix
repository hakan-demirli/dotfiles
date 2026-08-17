{ pkgs, ... }:
{
  imports = [
    ./development.nix
    ./headless-minimal.nix
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = false;
    plugins = [ pkgs.vimPlugins.nvim-lspconfig ];
  };

}
