{
  config,
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
    _name: node:
    "${node.hostName} CPUs=${toString node.cores} RealMemory=${toString node.ram_mb} State=UNKNOWN"
  ) slurmClusterHardware;
  computeNodesHardware = lib.filterAttrs (
    _name: node: !(node.isSlurmMaster or false)
  ) slurmClusterHardware;
  computeNodeNamesForPartition = lib.concatStringsSep "," (
    map (node: node.hostName) (lib.attrValues computeNodesHardware)
  );
  tracedNodeNameList = builtins.trace ''
    --- SLURM DEBUG ---
    slurmClusterHardware: ${builtins.toJSON slurmClusterHardware}
    masterNodeName: ${masterNodeName}
    isMaster: ${toString isMaster}
    computeNodeNamesForPartition: ${computeNodeNamesForPartition}
    Generated nodeNameList: ${builtins.toJSON nodeNameList}
    ---------------------
  '' nodeNameList;
in
{
  services = {
    timesyncd.enable = true;
    munge.enable = true;

    slurm = {
      server.enable = isMaster;
      client.enable = true;
      controlMachine = masterNodeName;
      clusterName = "nixos-slurm";
      procTrackType = "proctrack/pgid";

      nodeName = tracedNodeNameList;

      partitionName = [
        "master Nodes=${masterNodeName} MaxTime=INFINITE State=UP"
        "compute Nodes=${computeNodeNamesForPartition} Default=YES MaxTime=INFINITE State=UP"
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
  users.groups.slurm = { };
}
