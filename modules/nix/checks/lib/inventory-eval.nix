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
    roleCount = toString (lib.length (lib.attrNames inventory.roles));
    hostCount = toString (lib.length (lib.attrNames inventory.hosts));
    teamCount = toString (lib.length (lib.attrNames inventory.teams));
    clusterCount = toString (lib.length (lib.attrNames inventory.clusters));
    tierCount = toString (lib.length (lib.attrNames inventory.accessTiers));
    switchCount = toString (lib.length (lib.attrNames inventory.switches));
    projectCount = toString (lib.length (lib.attrNames inventory.projects));
    comboCount = toString (lib.length (lib.attrNames inventory.hostsByCombo));
  }
  ''
    echo "roles=$roleCount hosts=$hostCount teams=$teamCount clusters=$clusterCount" > $out
    echo "tiers=$tierCount switches=$switchCount projects=$projectCount combos=$comboCount" >> $out
  ''
