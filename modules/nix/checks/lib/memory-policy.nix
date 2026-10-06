{
  pkgs,
  self,
  lib,
}:
let
  hosts = lib.mapAttrs (_: host: host.config) self.nixosConfigurations;

  policy = config: {
    earlyoom-kills-single-processes =
      config.services.earlyoom.enable && !lib.elem "-g" config.services.earlyoom.extraArgs;
    zswap-compresses-swap-with-shrinker =
      config.boot.zswap.enable
      && config.boot.zswap.compressor == "zstd"
      && config.boot.zswap.shrinkerEnabled
      && !config.zramSwap.enable;
    swap-device-backs-zswap = config.swapDevices != [ ];
  };

  failures = lib.concatLists (
    lib.mapAttrsToList (
      name: config:
      map (rule: "${name}:${rule}") (lib.attrNames (lib.filterAttrs (_: passed: !passed) (policy config)))
    ) hosts
  );
in
pkgs.runCommand "memory-policy"
  {
    hostCount = toString (lib.length (lib.attrNames hosts));
    failureCount = toString (lib.length failures);
    failureNames = lib.concatStringsSep "," failures;
  }
  ''
    if [ "$hostCount" = 0 ]; then
      echo "memory policy found no NixOS hosts" >&2
      exit 1
    fi
    if [ "$failureCount" != 0 ]; then
      echo "failed fleet memory policy checks: $failureNames" >&2
      exit 1
    fi
    touch "$out"
  ''
