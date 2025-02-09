{
  description = "My NixOS home-manager config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
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
        dotfilesDir = "/home/emre/Desktop/dotfiles";
        gdriveDir = "/home/emre/Desktop/gdrive";
      };
    in
    {
      # sudo nix-rebuild switch --flake ~/Desktop/dotfiles/#emre
      nixosConfigurations."emre" = nixpkgs.lib.nixosSystem {
        specialArgs = {
          systemSettings = baseSystemSettings // {
            profile = "personal";
            hostname = "nixos";
            threads = 16;
          };
          userSettings = baseUserSettings;
        };

        modules = [
          ./profiles/personal/configuration.nix
          ./overlay.nix
        ];
      };

      # sudo nix-rebuild switch --flake ~/Desktop/dotfiles/#server
      nixosConfigurations."server" = nixpkgs.lib.nixosSystem {
        specialArgs = {
          systemSettings = baseSystemSettings // {
            profile = "server";
            threads = 16;
            hostname = "nixos-server";
          };
          userSettings = baseUserSettings;
        };

        modules = [
          ./profiles/server/configuration.nix
          ./overlay.nix
        ];
      };

      # sudo nix-rebuild switch --flake ~/Desktop/dotfiles/#vm
      nixosConfigurations."vm" = nixpkgs.lib.nixosSystem {
        specialArgs = {
          systemSettings = baseSystemSettings // {
            profile = "vm";
            threads = 16;
            hostname = "nixos-vm";
          };
          userSettings = baseUserSettings;
        };

        modules = [
          ./profiles/vm/configuration.nix
          ./overlay.nix
        ];
      };

      # home-manager switch --flake ~/Desktop/dotfiles/#emre
      homeConfigurations."emre" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = baseSystemSettings.system;
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
          systemSettings = baseSystemSettings // {
            profile = "personal";
            threads = 16;
          };
          userSettings = baseUserSettings;
        };

        modules = [
          ./profiles/personal/home.nix
          ./overlay.nix
        ];
      };
      # home-manager switch --flake ~/Desktop/dotfiles/#vm
      homeConfigurations."vm" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = baseSystemSettings.system;
          config.allowUnfree = true;
        };
        extraSpecialArgs = {
          inherit inputs;
          systemSettings = baseSystemSettings // {
            profile = "vm";
            threads = 16;
          };
          userSettings = baseUserSettings;
        };

        modules = [
          ./profiles/vm/home.nix
          ./overlay.nix
        ];
      };
    };
}
