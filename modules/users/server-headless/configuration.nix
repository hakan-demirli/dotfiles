{
  inputs,
  ...
}:
{
  # Self-contained server-headless user home-manager configuration module
  # Does not depend on any legacy files
  flake.modules.homeManager.user-server-headless = { config, pkgs, lib, ... }:
  let
    username = "emre";
    desktopDir = "/home/${username}/Desktop";
    historyFile = "${desktopDir}/history";
  in
  {
    targets.genericLinux = {
      enable = true;
    };

    # XDG directories configuration
    xdg = {
      enable = true;
      userDirs = {
        enable = true;
        createDirectories = true;
        desktop = desktopDir;
        documents = "${desktopDir}/documents";
        download = "${desktopDir}/download";
        videos = "${desktopDir}/videos";
        music = desktopDir;
        pictures = desktopDir;
        publicShare = desktopDir;
        templates = desktopDir;
      };
    };

    # Bash configuration
    programs.bash = {
      enable = true;
      enableCompletion = true;
      historyFile = historyFile;
      historyFileSize = 10000000;
      historySize = 10000000;
      historyControl = [ "ignoredups" "ignorespace" ];
      shellOptions = [
        "histappend"
        "checkwinsize"
        "extglob"
        "globstar"
        "checkjobs"
        "autocd"
      ];
      bashrcExtra = ''
        # Prompt history append
        PROMPT_COMMAND="history -a;$PROMPT_COMMAND"

        # Better less defaults
        export LESS='-R --use-color -Dd+r$Du+b'

        # fzf integration
        if command -v fzf &> /dev/null; then
          eval "$(fzf --bash)"
        fi
      '';
      initExtra = ''
        # Starship prompt
        if command -v starship &> /dev/null; then
          eval "$(starship init bash)"
        fi
      '';
    };

    programs = {
      gpg.homedir = "${config.xdg.dataHome}/gnupg";
      home-manager.enable = true;
      starship.enable = true;
      direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableBashIntegration = true;
      };
    };

    home = {
      inherit username;
      homeDirectory = "/home/${username}";
      stateVersion = "25.05";
    };

    home.packages = with pkgs; [
      # dev-essentials
      git
      gnumake
      cmake
      gcc
      rsync

      # editors
      neovim

      # tools-cli
      btop
      fzf
      ripgrep
      fd
      jq
      yq
      tree
      wget
      curl
      file
      unzip
      zip

      # server-cli
      tmux
      htop
    ];
  };
}
