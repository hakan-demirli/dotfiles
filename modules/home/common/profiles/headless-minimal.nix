{ config, ... }:
{
  programs = {
    fzf.enable = true;

    starship = {
      enable = true;
      enableBashIntegration = true;
    };

    tmux = {
      enable = true;
      terminal = "tmux-256color";
      keyMode = "vi";
      historyLimit = 100000;
    };

    yazi = {
      enable = true;
      enableBashIntegration = true;
      shellWrapperName = "f";
    };
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
