{
  config,
  pkgs,
  lib,
  slurmClusterHardware,
  ...
}:
let
  masterNode = lib.findFirst (node: node.isSlurmMaster or false) null (
    lib.attrValues slurmClusterHardware
  );
  masterNodeName =
    if masterNode == null then
      throw "No Slurm master found. Please set 'slurmMaster = true;' for exactly one node in your flake.nix."
    else
      masterNode.hostName;
  isMaster = config.networking.hostName == masterNodeName;
  nodeNameList = lib.mapAttrsToList (
    name: node:
    "${node.hostName} CPUs=${toString node.cores} RealMemory=${toString node.ram_mb} State=UNKNOWN"
  ) slurmClusterHardware;
  allNodeNamesForPartition = lib.concatStringsSep "," (
    map (node: node.hostName) (lib.attrValues slurmClusterHardware)
  );
  tracedNodeNameList = builtins.trace ''
    --- SLURM DEBUG ---
    slurmClusterHardware: ${builtins.toJSON slurmClusterHardware}
    masterNodeName: ${masterNodeName}
    isMaster: ${toString isMaster}
    Generated nodeNameList: ${builtins.toJSON nodeNameList}
    ---------------------
  '' nodeNameList;
in
{
  services.timesyncd.enable = true;
  services.munge.enable = true;
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
  users.groups.slurm = { };

  services.slurm = {
    server.enable = isMaster;

    client.enable = true;

    controlMachine = masterNodeName;

    clusterName = "nixos-slurm";
    procTrackType = "proctrack/pgid";

    nodeName = tracedNodeNameList;

    partitionName = [
      "debug Nodes=${allNodeNamesForPartition} Default=YES MaxTime=INFINITE State=UP"
    ];

    extraConfig = ''
      AuthType=auth/none
      CryptoType=crypto/none
    '';
  };
}
