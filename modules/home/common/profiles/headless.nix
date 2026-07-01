{
  pkgs,
  config,
  ...
}:
{
  home.packages = with pkgs; [
    lazygit
    tmux
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

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    keyMode = "vi";
    historyLimit = 100000;
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = false;
      desktop = "${config.home.homeDirectory}/Desktop";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      videos = "${config.home.homeDirectory}/Videos";
    };
  };
}
