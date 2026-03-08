{
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      common-packages = inputs.self.lib.mkPackages { inherit pkgs inputs; };
      barebonePackages =
        common-packages.dev-essentials
        ++ common-packages.editors
        ++ common-packages.lsp
        ++ common-packages.tools-cli
        ++ [
          pkgs.ncurses
          pkgs.direnv
          pkgs.openssl
          pkgs.glibcLocalesUtf8
          pkgs.kitty.terminfo
          pkgs.tailscale
          pkgs.btop
          pkgs.coreutils
          pkgs.zstd
          pkgs.gnutar
          pkgs.util-linux
          pkgs.rsync
          pkgs.gnugrep
          pkgs.gawk
          pkgs.nix
        ];
    in
    {
      packages.barebone = pkgs.buildEnv {
        name = "barebone";
        paths = barebonePackages;
        meta.description = "Barebone development environment";
      };
    };
}
