{ inputs, lib, ... }:
{
  perSystem =
    { system, ... }:
    let
      upstreamChecks = inputs.infra-lib.checks.${system} or { };
      upstreamApps = inputs.infra-lib.apps.${system} or { };

      isTest = name: _: lib.hasPrefix "test-" name;

      importedChecks = lib.filterAttrs isTest upstreamChecks;
      importedApps = lib.filterAttrs isTest upstreamApps;
    in
    {
      checks = importedChecks;
      apps = importedApps;
    };
}
