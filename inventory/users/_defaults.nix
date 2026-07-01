{ lib, ... }:
{
  kind = lib.mkDefault "human";
  cohort = lib.mkDefault "staff";
  xrdp_access = lib.mkDefault false;

  system_account = {
    shell = lib.mkForce "bash";
  };
}
