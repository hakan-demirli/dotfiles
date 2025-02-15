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
    let
      # ---- BASE SYSTEM SETTINGS ---- #
      baseSystemSettings = {
        system = "x86_64-linux";
        timezone = "Europe/Istanbul";
        locale = "en_US.UTF-8";
        locale_extra = "en_GB.UTF-8";
      };

      # ----- BASE USER SETTINGS ----- #
      baseUserSettings = {
        username = "emre";
        name = "EHD";
        dotfilesDir = "/home/emre/Desktop/dotfiles"; # must be an abs path
        gdriveDir = "/home/emre/Desktop/gdrive"; # must be an abs path
      };
    in
    {
      nixosConfigurations = {
        "laptop" = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;

            systemSettings = baseSystemSettings // {
              # a_custom_var = 16;
            };
            userSettings = baseUserSettings;
          };
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

            systemSettings = baseSystemSettings // {
              # a_custom_var = 16;
            };
            userSettings = baseUserSettings;
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
