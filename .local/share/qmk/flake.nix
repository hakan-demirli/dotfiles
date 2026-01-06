{
  description = "A simple flake for QMK firmware development";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs }:
    {
      devShell.x86_64-linux =
        with nixpkgs.legacyPackages.x86_64-linux;
        mkShell {
          buildInputs = [
            qmk # QMK package from nixpkgs
            git # To clone QMK firmware repository
          ];

          shellHook = ''
            echo "Setting up QMK firmware in the current directory..."
            make install
          '';
        };
    };
}
