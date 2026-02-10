{
  inputs,
  ...
}:
let
  username = "emre";
  desktopDir = "/home/${username}/Desktop";
  historyFile = "${desktopDir}/history";
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));

  flake.modules.homeManager.server-headless =
    { config, pkgs, ... }:
    let
      common-packages = import (inputs.self + /pkgs/common/packages.nix) { inherit pkgs inputs; };
      gpgPublicKeyFile = pkgs.writeText "yubikey-gpg-public.asc" publicData.yubikey.gpg_public_key;
    in
    {
      imports = [
        (import (inputs.self + /pkgs/common/bash.nix) {
          bashConfigDir = inputs.self + /.config/bash;
          inherit historyFile;
        })
        (import (inputs.self + /pkgs/common/xdg.nix) {
          inherit pkgs inputs;
          inherit desktopDir;
          enablePortal = false;
        })
      ];

      targets.genericLinux = {
        enable = true;
      };

      xdg = {
        enable = true;
        userDirs = {
          enable = true;
          createDirectories = false;
          desktop = desktopDir;
          documents = "${config.home.homeDirectory}/Documents";
          download = "${config.home.homeDirectory}/Downloads";
          videos = "${config.home.homeDirectory}/Videos";
        };
      };

      programs.bash = {
        enable = true;
        enableCompletion = true;
        inherit historyFile;
        shellOptions = [
          "histappend"
          "checkwinsize"
          "extglob"
          "globstar"
          "checkjobs"
          "autocd"
        ];
        bashrcExtra = ''
          # Better less defaults
          export LESS='-R --use-color -Dd+r$Du+b'
        '';
      };

      programs = {
        gpg = {
          enable = true;
          publicKeys = [
            {
              source = gpgPublicKeyFile;
              trust = 5;
            }
          ];
        };
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
        ++ common-packages.tools-cli
        ++ common-packages.server-cli
        ++ common-packages.ai
        ++ common-packages.lsp;
    };
in
{
  inherit flake;
}
