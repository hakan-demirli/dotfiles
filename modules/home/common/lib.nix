{
  mkHomeConfigurations =
    {
      inputs,
      homeRoot,
    }:
    let
      inherit (inputs.nixpkgs) lib;

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
          hasNvidia,
        }:
        {
          id = name;
          inherit system hasNvidia;
          os = "linux";
          deploymentRoles = [ ];
          topologyRoles = [ ];
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
          system,
          profile,
          hasNvidia,
          opencode,
        }:
        let
          facts = stubFacts { inherit name system hasNvidia; };
        in
        inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = {
            inherit
              inputs
              facts
              profile
              opencode
              ;
          };
          modules = [ (homeRoot + "/${user}") ];
        };

      profiles = {
        desktop = {
          profile = "desktop";
          system = "x86_64-linux";
          hasNvidia = false;
        };
        desktop-nvidia = {
          profile = "desktop";
          system = "x86_64-linux";
          hasNvidia = true;
        };
        headless = {
          profile = "headless";
          system = "x86_64-linux";
          hasNvidia = false;
        };
      };

      configurations = profiles // {
        vps-oracle-0 = {
          profile = "headless-minimal";
          system = inputs.self.lib.inventory.hosts.vps-oracle-0.hardware.arch;
          hasNvidia = false;
        };
      };

      opencodeServer = {
        configuration = "vps-oracle-0";
        address = "100.64.0.1";
        port = 4096;
      };

      opencodeEndpoint =
        configuration:
        lib.throwIfNot (configurations ? ${opencodeServer.configuration})
          "opencode server configuration ${opencodeServer.configuration} has no home configuration"
          {
            inherit (opencodeServer) address port;
            role = if configuration == opencodeServer.configuration then "server" else "client";
          };

      discoveredUsers =
        if !builtins.pathExists homeRoot then
          [ ]
        else
          lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir homeRoot));
    in
    lib.listToAttrs (
      lib.concatMap (
        uid:
        lib.mapAttrsToList (pname: pcfg: {
          name = "${uid}@${pname}";
          value = mkHome (
            pcfg
            // {
              user = uid;
              name = "${uid}.${pname}";
              opencode = opencodeEndpoint pname;
            }
          );
        }) configurations
      ) discoveredUsers
    );
}
