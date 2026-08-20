{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cluster-flow-collector;
  goflow2 = pkgs.goflow2.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./goflow2-psamp-sampling-rate.patch ];
  });
  listenHost =
    if lib.hasInfix ":" cfg.listenAddress then "[${cfg.listenAddress}]" else cfg.listenAddress;
  metricsHost =
    if lib.hasInfix ":" cfg.metricsAddress then "[${cfg.metricsAddress}]" else cfg.metricsAddress;
in
{
  options.services.cluster-flow-collector = {
    enable = lib.mkEnableOption "NetFlow and IPFIX collection";
    listenAddress = lib.mkOption {
      type = lib.types.str;
      example = "100.64.0.1";
    };
    netflowPort = lib.mkOption {
      type = lib.types.port;
      default = 2055;
    };
    metricsAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    metricsPort = lib.mkOption {
      type = lib.types.port;
      default = 8081;
    };
    workers = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
    };
    queueSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 16384;
    };
    cpuQuotaPercent = lib.mkOption {
      type = lib.types.ints.positive;
      default = 50;
    };
    memoryMaxMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 256;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.goflow2 = {
      description = "NetFlow and IPFIX collector";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network-online.target"
        "tailscaled.service"
      ];
      after = [
        "network-online.target"
        "tailscaled.service"
      ];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe' goflow2 "goflow2")
          "-listen=netflow://${listenHost}:${toString cfg.netflowPort}?workers=${toString cfg.workers}&queue_size=${toString cfg.queueSize}"
          "-addr=${metricsHost}:${toString cfg.metricsPort}"
          "-format=json"
          "-transport=file"
        ];
        CPUQuota = "${toString cfg.cpuQuotaPercent}%";
        CPUWeight = 25;
        DynamicUser = true;
        MemoryMax = "${toString cfg.memoryMaxMiB}M";
        Nice = 5;
        OOMScoreAdjust = 250;
        Restart = "on-failure";
        RestartSec = "5s";
        TasksMax = 64;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
  };
}
