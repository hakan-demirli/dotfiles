{
  allowsPersonalData =
    facts:
    builtins.elem (facts.ownership.class or null) [
      "personal"
      "leased"
    ];

  mkUnstablePkgs =
    {
      inputs,
      pkgs,
    }:
    import inputs.nixpkgs-unstable {
      inherit (pkgs.stdenv.hostPlatform) system;
      inherit (pkgs) config;
    };

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
          host ? null,
        }:
        let
          facts =
            if host == null then
              stubFacts { inherit name system hasNvidia; }
            else
              inputs.self.lib.hostFacts.${host.id}
              // {
                inherit system hasNvidia;
                inherit (host) ownership;
              };
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

      configurations =
        uid:
        profiles
        //
          lib.mapAttrs
            (_: host: {
              inherit host;
              profile =
                if lib.elem "laptop" host.deployment_roles then
                  "desktop"
                else if host.location.kind == "cloud-vm" then
                  "headless-minimal"
                else
                  "headless";
              system = host.hardware.arch;
              hasNvidia = lib.elem host.hardware.gpu [
                "nvidia"
                "amd+nvidia"
                "intel+nvidia"
              ];
            })
            (
              lib.filterAttrs (
                _: host:
                host.hardware.os == "linux"
                && host.ownership.owner == uid
                && !lib.elem host.state [
                  "planned"
                  "retired"
                ]
              ) inputs.self.lib.inventory.hosts
            );

      opencodeEndpoint = {
        address = "127.0.0.1";
        port = 4096;
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
        lib.concatLists (
          lib.mapAttrsToList (
            pname: pcfg:
            let
              value = mkHome (
                pcfg
                // {
                  user = uid;
                  name = "${uid}.${pname}";
                  opencode = opencodeEndpoint;
                }
              );
              names = lib.unique (
                [ "${uid}@${pname}" ]
                ++
                  lib.optional (pcfg ? host)
                    "${inputs.self.lib.inventory.users.${uid}.system_account.username}@${pname}"
              );
            in
            map (name: { inherit name value; }) names
          ) (configurations uid)
        )
      ) discoveredUsers
    );
}
