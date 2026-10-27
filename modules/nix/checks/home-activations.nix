{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      homeLibFile = ../../home/common/lib.nix;

      targets =
        if !builtins.pathExists homeLibFile then
          [ ]
        else
          (import homeLibFile).mkHomeTargets {
            inherit inputs;
            homeRoot = ../../home/users;
          };

      homeChecks = lib.listToAttrs (
        map (
          target:
          let
            id = lib.replaceStrings [ "@" ] [ "-" ] target.name;
          in
          {
            name = "home-${id}";
            value =
              pkgs.runCommand "check-home-${id}"
                { target = inputs.self.homeConfigurations.${target.name}.activationPackage; }
                ''
                  test -e "$target"
                  touch "$out"
                '';
          }
        ) (lib.filter (target: target.system == system) targets)
      );
    in
    {
      checks = homeChecks;
    };
}
