{
  pkgs,
  self,
  lib,
}:
let
  home = self.homeConfigurations."user-0@vps-oracle-0";
  packageNames = map lib.getName home.config.home.packages;
  requiredPackages = [
    "btop"
    "curl"
    "git"
    "jq"
    "rsync"
    "tmux"
    "vim"
  ];
  developmentPackages = [
    "aichat"
    "asm-lsp"
    "claude-code"
    "clang-tools"
    "dap-checked"
    "ffmpeg"
    "ffmpeg-full"
    "helix"
    "lua-language-server"
    "pyright"
    "raider"
    "rust-analyzer"
    "uncomment"
    "vscode-langservers-extracted"
    "yaml-language-server"
  ];
  checks = {
    uses-inventory-platform =
      home.pkgs.stdenv.hostPlatform.system == self.lib.inventory.hosts.vps-oracle-0.hardware.arch;
    has-ops-essentials = lib.all (name: lib.elem name packageNames) requiredPackages;
    excludes-development-packages = lib.all (name: !lib.elem name packageNames) developmentPackages;
    excludes-development-programs =
      !home.config.programs.direnv.enable
      && !home.config.programs.gh.enable
      && !home.config.programs.neovim.enable
      && !home.config.programs.starship.enable;
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
