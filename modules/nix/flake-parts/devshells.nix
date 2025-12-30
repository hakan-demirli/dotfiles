{
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    let
      common-packages = import (inputs.self + /pkgs/common/packages.nix) { inherit pkgs inputs; };
      barebonePackages =
        common-packages.dev-essentials
        ++ common-packages.editors
        ++ common-packages.lsp
        ++ common-packages.tools-cli
        ++ [
          # additional essentials
          pkgs.ncurses
          pkgs.direnv
        ];
    in
    {
      devShells.barebone = pkgs.mkShell {
        packages = barebonePackages;
      };
    };
}
