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
      moduleCacheBudget = 256 * 1024 * 1024;

      hostChecks = lib.listToAttrs (
        map (h: {
          name = "host-${h}";
          value =
            let
              cfg = cfgFor h;
              kernelModules = lib.optionals pkgs.stdenv.hostPlatform.isLinux (
                lib.unique cfg.config.boot.extraModulePackages
              );
              retainModule =
                package:
                let
                  closure = pkgs.closureInfo { rootPaths = [ package ]; };
                in
                ''
                  size=$(<${closure}/total-nar-size)
                  if (( size <= remaining )); then
                    ln -s ${package} "$out/$(basename ${package})"
                    remaining=$((remaining - size))
                  else
                    echo "Skipping CI cache retention for ${package.name}: $size bytes exceeds remaining budget $remaining"
                  fi
                '';
            in
            if cfg == null then
              pkgs.runCommand "missing-${h}" { } "echo missing ${h}; exit 1"
            else
              pkgs.runCommand "check-host-${h}" { target = cfg.config.system.build.toplevel; } ''
                test -e "$target"
                mkdir -p "$out"
                remaining=${toString moduleCacheBudget}
                ${lib.concatMapStringsSep "\n" retainModule kernelModules}
              '';
        }) myHosts
      );
    in
    {
      checks = hostChecks;
    };
}
