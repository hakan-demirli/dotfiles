{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inventory = inputs.self.lib.inventory;

      hostsForSystem =
        sys:
        lib.filter (n: (inventory.hosts.${n}.hardware.arch or null) == sys) (lib.attrNames inventory.hosts);

      myHosts = hostsForSystem system;

      cfgFor = h: inputs.self.nixosConfigurations.${h} or inputs.self.darwinConfigurations.${h} or null;

      hasCfg = h: (inputs.self.nixosConfigurations ? ${h}) || (inputs.self.darwinConfigurations ? ${h});

      hostChecks = lib.listToAttrs (
        map (h: {
          name = "host-${h}";
          value =
            let
              cfg = cfgFor h;
            in
            if cfg == null then
              pkgs.runCommand "missing-${h}" { } "echo missing ${h}; exit 1"
            else
              cfg.config.system.build.toplevel;
        }) (lib.filter hasCfg myHosts)
      );
    in
    {
      checks = hostChecks;
    };
}
