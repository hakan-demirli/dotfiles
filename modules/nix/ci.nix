{ inputs, lib, ... }:
let
  platforms = {
    x86_64-linux = "ubuntu-24.04";
    aarch64-linux = "ubuntu-24.04-arm";
    aarch64-darwin = "macos-14";
  };
  costs = [
    "heavy"
    "light"
  ];

  trait =
    attribute: allowed: default: system: name:
    let
      value = inputs.self.checks.${system}.${name}.${attribute} or default;
    in
    if lib.elem value allowed then
      value
    else
      throw "checks.${system}.${name}.${attribute} is ${builtins.toJSON value}, expected one of: ${lib.concatStringsSep ", " allowed}";

  costOf = trait "ciCost" costs "light";

  jobs = inputs.nix-github-actions.lib.mkGithubMatrix {
    inherit (inputs.self) checks;
    inherit platforms;
  };
in
{
  flake.githubActions = jobs // {
    matrix.include = lib.concatMap (
      cost: lib.filter (entry: costOf entry.system entry.name == cost) jobs.matrix.include
    ) costs;

    external = inputs.nix-github-actions.lib.mkGithubMatrix {
      checks = lib.mapAttrs (_: packages: packages.externalBuilds or { }) inputs.self.legacyPackages;
      attrPrefix = "githubActions.external.checks";
      platforms = platforms // {
        x86_64-linux = "ubuntu-22.04";
      };
    };
  };
}
