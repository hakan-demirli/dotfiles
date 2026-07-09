{ inputs, ... }:
{
  flake.homeConfigurations =
    let
      inherit (inputs.nixpkgs) lib;

      homeRoot = ../home/users;

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
          user,
          system ? "x86_64-linux",
          profile ? "desktop",
          hasNvidia ? false,
        }:
        let
          facts = stubFacts { inherit name system hasNvidia; };
        in
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = {
            inherit inputs facts profile;
          };
          modules = [ (homeRoot + "/${user}") ];
        };

      profiles = {
        "desktop" = {
          profile = "desktop";
          hasNvidia = false;
        };
        "desktop-nvidia" = {
          profile = "desktop";
          hasNvidia = true;
        };
        "headless" = {
          profile = "headless";
          hasNvidia = false;
        };
      };

      discoveredUsers =
        if !builtins.pathExists homeRoot then
          [ ]
        else
          lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir homeRoot));

      entries = lib.listToAttrs (
        lib.concatMap (
          uid:
          lib.mapAttrsToList (pname: pcfg: {
            name = "${uid}@${pname}";
            value = pcfg // {
              user = uid;
            };
          }) profiles
        ) discoveredUsers
      );
    in
    lib.mapAttrs (name: cfg: mkHome (cfg // { inherit name; })) entries;
}
