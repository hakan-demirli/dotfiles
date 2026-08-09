{
  pkgs,
  self,
  lib,
}:
let
  inventory = self.lib.inventory;
in
pkgs.runCommand "inventory-eval"
  {
    deploymentRoleCount = toString (lib.length (lib.attrNames inventory.deploymentRoles));
    hostCount = toString (lib.length (lib.attrNames inventory.hosts));
    teamCount = toString (lib.length (lib.attrNames inventory.teams));
    clusterCount = toString (lib.length (lib.attrNames inventory.clusters));
    unixTierCount = toString (lib.length (lib.attrNames inventory.unixAccessTiers));
    switchCount = toString (lib.length (lib.attrNames inventory.switches));
    projectCount = toString (lib.length (lib.attrNames inventory.projects));
    comboCount = toString (lib.length (lib.attrNames inventory.hostsByCombo));
  }
  ''
    echo "deployment-roles=$deploymentRoleCount hosts=$hostCount teams=$teamCount clusters=$clusterCount" > $out
    echo "unix-tiers=$unixTierCount switches=$switchCount projects=$projectCount combos=$comboCount" >> $out
  ''
