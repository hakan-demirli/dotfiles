{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inventory = inputs.self.lib.inventory;

      buildable =
        host:
        lib.elem host.hardware.os [
          "linux"
          "darwin"
        ]
        && !lib.elem host.state [
          "planned"
          "retired"
        ];

      hostsForSystem =
        sys:
        lib.attrNames (
          lib.filterAttrs (_: host: buildable host && host.hardware.arch == sys) inventory.hosts
        );

      myHosts = hostsForSystem system;

      cfgFor = h: inputs.self.nixosConfigurations.${h} or inputs.self.darwinConfigurations.${h} or null;

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
        }) myHosts
      );
    in
    {
      checks = hostChecks;
    };
}
