{
  pkgs,
  config,
  inputs,
  ...
}:
let
  username = "emre";
  bashConfigDir = ../../.config/bash;
  historyFile = "$HOME/Desktop/history";
  common-packages = import ../common/packages.nix { inherit pkgs inputs; };
in
{
  imports = [
    (import ../common/xdg.nix {
      inherit pkgs inputs config;
      desktopDir = "/home/${username}/Desktop/";
    })
    (import ../common/bash.nix { inherit bashConfigDir historyFile; })
  ];

  targets.genericLinux = {
    enable = true;
    gpu.enable = false;
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

  home.packages =
    common-packages.dev-essentials
    ++ common-packages.editors
    ++ common-packages.ai
    ++ common-packages.lsp
    ++ common-packages.tools-cli
    ++ common-packages.server-cli;
}
