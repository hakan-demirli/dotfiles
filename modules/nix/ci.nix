{ inputs, lib, ... }:
let
  portableSystem = "x86_64-linux";

  trait =
    attribute: allowed: default: system: name:
    let
      value = inputs.self.checks.${system}.${name}.${attribute} or default;
    in
    if lib.elem value allowed then
      value
    else
      throw "checks.${system}.${name}.${attribute} is ${builtins.toJSON value}, expected one of: ${lib.concatStringsSep ", " allowed}";

  scopeOf = trait "ciScope" [
    "native"
    "portable"
  ] "native";

  checks = lib.mapAttrs (
    system: lib.filterAttrs (name: _: scopeOf system name == "native" || system == portableSystem)
  ) inputs.self.checks;

  inherit (inputs.self.lib) inventory;
  ciHost = lib.head inventory.services.nixbot.hosts;
  archOf = id: inventory.hosts.${id}.hardware.arch;
  ciSystems = lib.unique (map archOf ([ ciHost ] ++ inventory.hostsByDeploymentRole.server-dev));
  ciPkgs = inputs.nixpkgs.legacyPackages.${archOf ciHost};
  effects = inputs.nixbot.lib.effects { pkgs = ciPkgs; };
  inherit (inputs.self.lib.forge.identities) bot;
in
{
  flake = {
    hydraJobs = {
      checks = lib.genAttrs ciSystems (system: checks.${system} or { });
      devices = lib.genAttrs (lib.intersectLists ciSystems (lib.attrNames inputs.self.legacyPackages)) (
        system:
        let
          packages = inputs.self.legacyPackages.${system};
        in
        packages.deviceBuilds or { } // packages.externalBuilds or { }
      );
    };

    herculesCI =
      { primaryRepo, ... }:
      inputs.infra-lib.lib.mkForgeFlow {
        inherit effects primaryRepo bot;
        inherit (ciPkgs) git;
        update = {
          hour = 7;
          minute = 17;
        };
      };
  };
}
