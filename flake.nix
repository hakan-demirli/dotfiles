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

    small-apps = {
      url = "github:hakan-demirli/small-apps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      # Helper function to reduce repetition for each system configuration.
      mkSystem =
        { hostConfig, system }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
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
        laptop = mkSystem {
          hostConfig = ./hosts/laptop/configuration.nix;
          system = "x86_64-linux";
        };
        vm_local = mkSystem {
          hostConfig = ./hosts/vm_local/configuration.nix;
          system = "x86_64-linux";
        };
        vm_oracle_x86 = mkSystem {
          hostConfig = ./hosts/vm_oracle_x86/configuration.nix;
          system = "x86_64-linux";
        };
        server_1 = mkSystem {
          hostConfig = ./hosts/server_1/configuration.nix;
          system = "x86_64-linux";
        };
        vm_oracle_aarch64 = mkSystem {
          hostConfig = ./hosts/vm_oracle_aarch64/configuration.nix;
          system = "aarch64-linux";
        };
      };
    };
}
