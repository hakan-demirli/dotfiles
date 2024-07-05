{
  description = "Python flake env";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          shellHook = ''
            echo "Sup."
          '';
          packages = with pkgs; [
            python3
            python3Packages.pygobject3
            python3Packages.requests

            wrapGAppsHook
            gobject-introspection
            libappindicator
          ];
        };
      }
    );
}
