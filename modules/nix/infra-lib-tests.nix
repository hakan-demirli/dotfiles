{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      upstreamApps = inputs.infra-lib.apps.${system} or { };

      isTest = name: _: lib.hasPrefix "test-" name;

      importedApps = lib.filterAttrs isTest upstreamApps;
    in
    {
      apps = importedApps;
    };
}
