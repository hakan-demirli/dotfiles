_: {
  imports = [
    ./development.nix
    ./headless-minimal.nix
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    extraConfig = ''
      set number
      set relativenumber
      set expandtab
      set tabstop=4
      set shiftwidth=4
      set termguicolors
      set ignorecase
      set smartcase
      set mouse=a
      set clipboard^=unnamedplus
    '';
  };

}
