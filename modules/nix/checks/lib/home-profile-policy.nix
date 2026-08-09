{
  pkgs,
  self,
  lib,
  inputs,
}:
let
  home = self.homeConfigurations."user-0@vps-oracle-0";
  packageGroups = import ../../../home/common/package-groups.nix {
    inherit inputs lib;
    inherit (home) pkgs;
  };
  packagePaths = map toString home.config.home.packages;
  minimalPackagePaths = map toString packageGroups.minimal;
  developmentPackagePaths = map toString packageGroups.developmentAdditions;
  checks = {
    uses-inventory-platform =
      home.pkgs.stdenv.hostPlatform.system == self.lib.inventory.hosts.vps-oracle-0.hardware.arch;
    has-minimal-packages = lib.all (path: lib.elem path packagePaths) minimalPackagePaths;
    excludes-development-packages = lib.all (path: !lib.elem path packagePaths) developmentPackagePaths;
    excludes-development-programs =
      !home.config.programs.direnv.enable
      && !home.config.programs.gh.enable
      && !home.config.programs.neovim.enable;
    has-minimal-shell-tools =
      home.config.programs.fzf.enable
      && home.config.programs.starship.enable
      && home.config.programs.starship.enableBashIntegration
      && home.config.programs.tmux.enable
      && home.config.programs.yazi.enable
      && home.config.programs.yazi.enableBashIntegration
      && home.config.programs.yazi.shellWrapperName == "f";
    deploys-shared-config =
      lib.all (name: builtins.hasAttr name home.config.xdg.configFile) [
        "bash"
        "starship.toml"
        "yazi"
      ]
      && builtins.hasAttr ".local/bin" home.config.home.file;
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
pkgs.runCommand "home-profile-policy"
  {
    failureCount = toString (lib.length failures);
    failureNames = lib.concatStringsSep "," failures;
  }
  ''
    if [ "$failureCount" != 0 ]; then
      echo "failed Home Manager profile checks: $failureNames" >&2
      exit 1
    fi
    touch "$out"
  ''
