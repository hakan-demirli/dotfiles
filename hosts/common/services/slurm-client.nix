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
  masterNodeName = if masterNode == null then throw "No Slurm master found." else masterNode.hostName;
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

  services.slurm.enableStools = true;

  services.slurm.controlMachine = masterNodeName;
  services.slurm.clusterName = "nixos-slurm";
  services.slurm.extraConfig = ''
    AuthType=auth/none
    CryptoType=crypto/none
  '';
}
