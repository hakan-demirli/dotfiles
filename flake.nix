{
  description = "My NixOS home-manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
      };
    };
  in {
    # sudo nixos-rebuild switch --flake ~/new/#myNixos
    nixosConfigurations = {
      myNixos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs system;};
        modules = [./nixos/configuration.nix];
      };
    };
    # TODO  nix run home-manager/master -- switch --flake .
    # homeConfiguration
  };
}
