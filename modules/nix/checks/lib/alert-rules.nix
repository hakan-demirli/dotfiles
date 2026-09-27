{ pkgs, self }:
let
  inherit (pkgs) lib;
  observabilityHosts = self.lib.inventory.hostsByDeploymentRole.mgmt-observability or [ ];
  ruleDirs = lib.unique (
    map (
      hid: self.nixosConfigurations.${hid}.config.services.cluster-vmalert.ruleDir
    ) observabilityHosts
  );
  ruleFiles = lib.concatMap (
    dir:
    lib.mapAttrsToList
      (
        name: _:
        pkgs.writeText "vmalert-${lib.removeSuffix ".nix" name}.yaml" (
          builtins.toJSON (import (dir + "/${name}"))
        )
      )
      (
        lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".nix" n && !lib.hasPrefix "_" n) (
          builtins.readDir dir
        )
      )
  ) ruleDirs;
in
assert lib.assertMsg (ruleFiles != [ ]) "alert-rules: no vmalert rule files found";
pkgs.runCommand "alert-rules" { nativeBuildInputs = [ pkgs.victoriametrics ]; } ''
  vmalert -dryRun ${lib.concatMapStringsSep " " (file: "-rule=${file}") ruleFiles}
  touch "$out"
''
