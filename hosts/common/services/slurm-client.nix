{
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
  services = {
    timesyncd.enable = true;
    munge.enable = true;
    slurm = {
      enableStools = true;
      controlMachine = masterNodeName;
      clusterName = "nixos-slurm";
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
