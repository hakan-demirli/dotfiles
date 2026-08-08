{ pkgs, self }:
let
  inherit (pkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;
  eligibleHosts = lib.filterAttrs (
    hostId: host:
    host.hardware.os == "linux"
    && host.hardware.arch == system
    && host.disko != null
    && host.disko.managed
    && host.disko.installer.enable
    && builtins.hasAttr hostId self.nixosConfigurations
  ) self.lib.inventory.hosts;
  expectedNames = map (hostId: "install-${hostId}") (lib.attrNames eligibleHosts);
  actualNames = lib.filter (lib.hasPrefix "install-") (lib.attrNames self.packages.${system});
  apps = self.apps.${system};

  hostContracts = lib.mapAttrsToList (
    hostId: host:
    let
      name = "install-${hostId}";
      installer = self.packages.${system}.${name};
      systemBuild = self.nixosConfigurations.${hostId}.config.system.build;
    in
    builtins.hasAttr name apps
    && installer.hostId == hostId
    && installer.expectedDisk == host.disko.root_disk
    && installer.targetSystem == systemBuild.toplevel
    && installer.diskoScript == systemBuild.diskoScript
  ) eligibleHosts;

  checks = {
    output-set-matches-opted-in-inventory = actualNames == expectedNames;
    every-package-uses-real-host-configuration = lib.all lib.id hostContracts;
  };
  failures = lib.attrNames (lib.filterAttrs (_: passed: !passed) checks);
in
pkgs.runCommand "inventory-installers"
  {
    failureCount = toString (lib.length failures);
    failureNames = lib.concatStringsSep "," failures;
  }
  ''
    if [ "$failureCount" != 0 ]; then
      echo "failed inventory installer checks: $failureNames" >&2
      exit 1
    fi
    touch "$out"
  ''
