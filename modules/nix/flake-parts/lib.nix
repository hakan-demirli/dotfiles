{
  inputs,
  lib,
  ...
}:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.attrsOf lib.types.raw;
    default = { };
  };

  options.flake.factory = lib.mkOption {
    type = lib.types.attrsOf lib.types.raw;
    default = { };
  };

  config.flake.lib = {

    stateVersion = "26.05";

    publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));

    mkPackages =
      { pkgs, inputs }: import (inputs.self + /pkgs/common/packages.nix) { inherit pkgs inputs; };

    mkNixos = system: name: {
      ${name} = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          inputs.self.modules.nixos.${name}
          { nixpkgs.hostPlatform = lib.mkDefault system; }
          inputs.home-manager.nixosModules.home-manager
          inputs.disko.nixosModules.disko
          inputs.impermanence.nixosModules.impermanence
          inputs.sops-nix.nixosModules.sops
        ];
      };
    };

    mkDarwin = system: name: {
      ${name} = inputs.nix-darwin.lib.darwinSystem {
        modules = [
          inputs.self.modules.darwin.${name}
          { nixpkgs.hostPlatform = lib.mkDefault system; }
          inputs.home-manager.darwinModules.home-manager
        ];
      };
    };

    mkHomeManager = system: name: {
      ${name} = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = inputs.nixpkgs.legacyPackages.${system};
        modules = [
          inputs.self.modules.homeManager.${name}
        ];
      };
    };

  };

  config.flake.factory = {
    firefox = args: import (inputs.self + /pkgs/firefox.nix) args;
    xdg = args: import (inputs.self + /pkgs/common/xdg.nix) args;
    bash = args: import (inputs.self + /pkgs/common/bash.nix) args;
  };
}
