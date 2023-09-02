{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # Available through 'nixos-rebuild --flake .#your-hostname'
      nixosConfigurations = {
        nixos = nixpkgs.lib.nixosSystem {
          modules = [ ./nixos/configuration.nix ];
        };
      };

      # Available through 'home-manager --flake .#your-username@your-hostname'
      homeConfigurations."emre" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ ./home.nix ];
      };
    };
}

# nix run home-manager -- init






# @attr usage is explained here
# https://nix.dev/tutorials/first-steps/nix-language

# https://github.com/Misterio77/nix-starter-configs

# extraSpecialArgs usage
# https://github.com/jonringer/nixpkgs-config

# nix run home-manager/master switch --flake .#username@hostname


# nix run home-manager -- switch
