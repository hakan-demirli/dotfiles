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
    {
      nixpkgs,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        "laptop" = nixpkgs.lib.nixosSystem {
          modules = [
            ./hosts/laptop/configuration.nix
            inputs.home-manager.nixosModules.home-manager
            inputs.disko.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
            ./overlay.nix
          ];
        };
        "vm" = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/vm/configuration.nix
            inputs.home-manager.nixosModules.home-manager
            inputs.disko.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
            ./overlay.nix
          ];
        };
      };
    };
}
