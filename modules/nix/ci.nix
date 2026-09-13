{ inputs, lib, ... }:
let
  platforms = {
    x86_64-linux = "ubuntu-24.04";
    aarch64-linux = "ubuntu-24.04-arm";
    aarch64-darwin = "macos-14";
  };
in
{
  flake.githubActions =
    (inputs.nix-github-actions.lib.mkGithubMatrix {
      inherit (inputs.self) checks;
      inherit platforms;
    })
    // {
      external = inputs.nix-github-actions.lib.mkGithubMatrix {
        checks = lib.mapAttrs (_: packages: packages.externalBuilds or { }) inputs.self.legacyPackages;
        attrPrefix = "githubActions.external.checks";
        inherit platforms;
      };
    };
}
