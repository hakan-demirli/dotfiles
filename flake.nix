{
  description = "dots";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence = {
      url = "github:nix-community/impermanence";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      # Helper function to reduce repetition for each system configuration.
      mkSystem =
        hostConfig:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            hostConfig
            inputs.home-manager.nixosModules.home-manager
            inputs.disko.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
            ./overlay.nix
          ];
        };
    in
    {
      nixosConfigurations = {
        laptop = mkSystem ./hosts/laptop/configuration.nix;
        vm = mkSystem ./hosts/vm/configuration.nix;
        server_1 = mkSystem ./hosts/server_1/configuration.nix;
      };
    };
}
