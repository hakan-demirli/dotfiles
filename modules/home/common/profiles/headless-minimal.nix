{
  pkgs,
  config,
  ...
}:
{
  home.packages = with pkgs; [
    btop
    curl
    git
    jq
    rsync
    vim
  ];

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
