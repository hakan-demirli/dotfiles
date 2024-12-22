{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default =
        let
          pythonEnv = pkgs.python312.withPackages (
            ps: with ps; [
              setuptools
              requests

              flask
              flask-cors

              flask-socketio
              eventlet
            ]
          );
        in
        pkgs.mkShell {
          packages = [
            pythonEnv
          ];
        };
    };
}
