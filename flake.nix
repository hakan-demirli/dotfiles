{
  description = "My NixOS home-manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    xremap-flake.url = "github:xremap/nix-flake";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    username = "emre";
    system = "x86_64-linux";
  in {
    # sudo nix-rebuild switch --flake ~/Desktop/dotfiles/#myNixos
    nixosConfigurations."myNixos" = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs username system;};
      modules = [./platforms/asustuf.nix];
    };
    # home-manager switch --flake ~/Desktop/dotfiles/#emre
    homeConfigurations."${username}" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = {inherit inputs username;};
      modules = [./platforms/home.nix];
    };
  };
}
