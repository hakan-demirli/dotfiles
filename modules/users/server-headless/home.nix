{
  inputs,
  ...
}:
let
  flake.modules.homeManager.server-headless =
    { config, pkgs, ... }:
    let
      inherit (config.home) homeDirectory;
      desktopDir = "${homeDirectory}/Desktop";
      historyFile = "${desktopDir}/history";
      common-packages = inputs.self.lib.mkPackages { inherit pkgs inputs; };
    in
    {
      imports = [
        (inputs.self.factory.bash {
          bashConfigDir = inputs.self + /.config/bash;
          inherit historyFile;
        })
        (inputs.self.factory.xdg {
          inherit pkgs inputs;
          inherit desktopDir;
          enablePortal = false;
        })
        inputs.self.modules.homeManager.services-opencode
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
        home-manager.enable = true;
        starship.enable = true;
        direnv = {
          enable = true;
          nix-direnv.enable = true;
          enableBashIntegration = true;
        };
      };

      home = {
        inherit (inputs.self.lib) stateVersion;
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
