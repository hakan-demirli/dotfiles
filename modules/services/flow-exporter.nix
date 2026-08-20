{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.cluster-flow-exporter;
  collectorHost =
    if lib.hasInfix ":" cfg.collectorAddress then "[${cfg.collectorAddress}]" else cfg.collectorAddress;
in
{
  options.services.cluster-flow-exporter = {
    enable = lib.mkEnableOption "sampled IPFIX flow export";
    interface = lib.mkOption {
      type = lib.types.str;
      default = "tailscale0";
    };
    collectorAddress = lib.mkOption {
      type = lib.types.str;
      example = "100.64.0.1";
    };
    collectorPort = lib.mkOption {
      type = lib.types.port;
      default = 2055;
    };
    samplingRate = lib.mkOption {
      type = lib.types.ints.positive;
      default = 256;
      description = "Capture one out of every N packets.";
    };
    captureLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 128;
      description = "Maximum packet bytes copied for flow classification.";
    };
    activeTimeoutSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
    };
    maxFlows = lib.mkOption {
      type = lib.types.ints.positive;
      default = 65536;
    };
    cpuQuotaPercent = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
    };
    memoryMaxMiB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 128;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.softflowd-flow-exporter = {
      description = "Sampled IPFIX flow exporter";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network-online.target"
      ]
      ++ lib.optional (cfg.interface == "tailscale0") "tailscaled.service";
      after = [
        "network-online.target"
      ]
      ++ lib.optional (cfg.interface == "tailscale0") "tailscaled.service";
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe' pkgs.softflowd "softflowd")
          "-d"
          "-c"
          "none"
          "-N"
          "-i"
          cfg.interface
          "-n"
          "${collectorHost}:${toString cfg.collectorPort}"
          "-v"
          "10"
          "-s"
          (toString cfg.samplingRate)
          "-C"
          (toString cfg.captureLength)
          "-m"
          (toString cfg.maxFlows)
          "-t"
          "maxlife=${toString cfg.activeTimeoutSeconds}"
          "-t"
          "expint=10"
          "not (udp and dst host ${cfg.collectorAddress} and dst port ${toString cfg.collectorPort})"
        ];
        AmbientCapabilities = [ "CAP_NET_RAW" ];
        CapabilityBoundingSet = [ "CAP_NET_RAW" ];
        CPUQuota = "${toString cfg.cpuQuotaPercent}%";
        CPUWeight = 10;
        DynamicUser = true;
        MemoryMax = "${toString cfg.memoryMaxMiB}M";
        Nice = 10;
        OOMScoreAdjust = 500;
        Restart = "on-failure";
        RestartSec = "5s";
        TasksMax = 32;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_PACKET"
          "AF_UNIX"
        ];
      };
    };
  };
}
