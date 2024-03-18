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
    # ---- SYSTEM SETTINGS ---- #
    systemSettings = {
      system = "x86_64-linux";
      hostname = "nixos";
      profile = "personal"; # select a profile defined from ./profiles directory
      timezone = "Europe/Istanbul";
      locale = "en_US.UTF-8"; # default locale
      locale_extra = "en_GB.UTF-8"; # extra locale
      threads = 16; # cpu threads
    };

    # ----- USER SETTINGS ----- #
    userSettings = rec {
      username = "emre"; # username
      name = "EHD"; # name/identifier
      dotfilesDir = "/home/${username}/Desktop/dotfiles"; # absolute path of the local repo
    };
  in {
    # sudo nix-rebuild switch --flake ~/Desktop/dotfiles/#myNixos
    nixosConfigurations."myNixos" = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit userSettings systemSettings;};

      modules = [(./. + "/profiles" + ("/" + systemSettings.profile) + "/configuration.nix")]; # load configuration.nix from selected PROFILE
    };
    # home-manager switch --flake ~/Desktop/dotfiles/#emre
    homeConfigurations."${userSettings.username}" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = systemSettings.system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = {
        inherit inputs systemSettings userSettings;
      };

      modules = [./profiles/personal/home.nix]; # load home.nix from selected PROFILE
    };
  };
}
