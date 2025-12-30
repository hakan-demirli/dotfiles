{
  inputs,
  ...
}:
{
  # SLURM cluster service
  flake.modules.nixos.services-slurm = { config, lib, ... }:
  let
    cfg = config.services.slurm-cluster;
    nodeNameList = map (node:
      "${node.hostName} CPUs=${toString node.cores} RealMemory=${toString node.ramMb} State=UNKNOWN"
    ) cfg.clusterNodes;

    computeNodes = builtins.filter (node: node.hostName != cfg.masterHostname) cfg.clusterNodes;
    computeNodeNames = lib.concatStringsSep "," (map (node: node.hostName) computeNodes);
  in
  {
    options.services.slurm-cluster = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable SLURM cluster participation (master and/or node)";
      };
      isMaster = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Is this the SLURM master node?";
      };
      masterHostname = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Hostname of the SLURM master node";
      };
      cores = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Number of CPU cores on this node";
      };
      ramMb = lib.mkOption {
        type = lib.types.int;
        default = 1024;
        description = "Amount of RAM in MB on this node";
      };
      clusterNodes = lib.mkOption {
        type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
        default = [];
        description = "List of all cluster nodes with hostName, cores, ramMb";
      };
    };

    config = lib.mkIf cfg.enable {
      services = {
        timesyncd.enable = true;
        munge.enable = true;

        slurm = {
          server.enable = cfg.isMaster;
          client.enable = true;
          controlMachine = cfg.masterHostname;
          clusterName = "nixos-slurm";
          procTrackType = "proctrack/pgid";

          nodeName = nodeNameList;

          partitionName = [
            "master Nodes=${cfg.masterHostname} MaxTime=INFINITE State=UP"
            "compute Nodes=${computeNodeNames} Default=YES MaxTime=INFINITE State=UP"
          ];

          extraConfig = ''
            AuthType=auth/none
            CryptoType=crypto/none
          '';
        };
      };

      environment.etc."munge/munge.key" = {
        text = "mungeverryweakkeybuteasytointegratoinatest";
        mode = "0400";
        user = "munge";
        group = "munge";
      };

      users.users.slurm = {
        isSystemUser = true;
        group = "slurm";
      };
      users.groups.slurm = {};
    };
  };
}
