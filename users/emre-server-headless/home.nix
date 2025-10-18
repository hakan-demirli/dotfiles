{
  pkgs,
  config,
  inputs,
  ...
}:
let
  username = "emre";
  bashConfigDir = ../../.config/bash;
  common-packages = import ../common/packages.nix { inherit pkgs inputs; };
in
{
  imports = [
    (import ../common/xdg.nix {
      inherit pkgs inputs config;
      desktopDir = "/home/${username}/Desktop/";
    })
  ];

  targets.genericLinux.enable = true;

  programs = {
    gpg.homedir = "${config.xdg.dataHome}/gnupg";
    home-manager.enable = true;
    starship.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
    };
    bash = {
      enable = true;
      historyFile = "$HOME/Desktop/history"; # persist hist in Desktop
      historyFileSize = -1;
      historySize = -1;
      historyControl = [
        "ignoredups"
        "erasedups"
      ];
      enableCompletion = true;
      bashrcExtra = ''
        PROMPT_COMMAND="history -a; history -r"
      '';
      initExtra = ''
        if [ -f "${bashConfigDir}/main.sh" ]; then
          source "${bashConfigDir}/main.sh"
        fi
      '';
    };
    fzf = {
      enable = true;
      defaultCommand = "${pkgs.fd}/bin/fd --type f";
      defaultOptions = [
        "--bind 'tab:toggle-up,btab:toggle-down'"
        "--info=inline"
        "--border"
        "--color=fg:-1,bg:-1,hl:#bd93f9"
        "--color=fg+:#f8f8f2,bg+:#282a36,hl+:#bd93f9"
        "--color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6"
        "--color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
        "--prompt='❯ '"
      ];
    };
  };

  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    stateVersion = "25.05";
  };

  home.packages =
    common-packages.dev-essentials
    ++ common-packages.editors
    ++ common-packages.ai
    ++ common-packages.lsp
    ++ common-packages.tools-cli
    ++ common-packages.server-cli;
}
