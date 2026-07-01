{
  lib,
  host,
  cluster,
  ...
}:
let
  operatorId =
    if host.ownership.operator != null then
      host.ownership.operator
    else
      throw "server-dev-2: host.ownership.operator must be set (borrowed hardware needs a named operator).";
  operator =
    cluster.users.${operatorId}
      or (throw "server-dev-2: operator '${operatorId}' is not a declared inventory user.");
  operatorUsername = operator.system_account.username;
in
{
  powerManagement.cpuFreqGovernor = "performance";

  systemd.tmpfiles.rules = [
    "d /persist/xilinx 0755 ${operatorUsername} users -"
  ];

  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
}
