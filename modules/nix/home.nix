{ inputs, ... }:
{
  flake.homeConfigurations =
    let
      lib = inputs.nixpkgs.lib;

      mkPkgs =
        system:
        import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowUnfreePredicate = _: true;
          };
        };

      stubFacts =
        {
          name,
          system,
          hasNvidia ? false,
        }:
        {
          id = name;
          inherit system hasNvidia;
          os = "linux";
          roles = [ ];
          cluster = null;
          mainboard = null;
          location = {
            kind = "laptop";
            site = null;
          };
          labels = { };
        };

      mkHome =
        {
          name,
          username,
          homeDirectory,
          system ? "x86_64-linux",
          profile ? "desktop",
          hasNvidia ? false,
          facts ? stubFacts { inherit name system hasNvidia; },
          extraModules ? [ ],
        }:
        let
          profileModule =
            if profile == "desktop" then
              ../home/desktop.nix
            else if profile == "headless" then
              ../home/headless.nix
            else
              throw "home: unknown profile '${profile}'";
        in
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = {
            inherit inputs facts;
          };
          modules = [
            ../home/default.nix
            profileModule
            (_: {
              home = {
                inherit username homeDirectory;
                stateVersion = "26.11";
              };
            })
          ]
          ++ extraModules;
        };

      entries = {
        emre = {
          username = "emre";
          homeDirectory = "/home/emre";
          system = "x86_64-linux";
          profile = "desktop";
        };

        emre-nvidia = {
          username = "emre";
          homeDirectory = "/home/emre";
          system = "x86_64-linux";
          profile = "desktop";
          hasNvidia = true;
        };

        emre-headless = {
          username = "emre";
          homeDirectory = "/home/emre";
          system = "x86_64-linux";
          profile = "headless";
        };
      };
    in
    lib.mapAttrs (name: cfg: mkHome (cfg // { inherit name; })) entries;
}
