{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      diagrams = import ./lib.nix {
        inherit lib;
        inventory = inputs.self.lib.inventory;
        intent = inputs.self.lib.intent;
      };
      d = {
        tailnet = diagrams.tailnet { inherit pkgs; };
        sshMatrix = diagrams.sshMatrix { inherit pkgs; };
        slurmSubmit = diagrams.slurmSubmit { inherit pkgs; };
        topology = diagrams.topology { inherit pkgs; };
        network = diagrams.network { inherit pkgs; };
        clusterAccess = diagrams.clusterAccess { inherit pkgs; };
        ownership = diagrams.ownership { inherit pkgs; };
        host = diagrams.host { inherit pkgs; };
      };
    in
    {
      packages = {
        diagrams-tailnet = d.tailnet;
        diagrams-ssh-matrix = d.sshMatrix;
        diagrams-slurm-submit = d.slurmSubmit;
        diagrams-topology = d.topology;
        diagrams-network = d.network;
        diagrams-cluster-access = d.clusterAccess;
        diagrams-ownership = d.ownership;
        diagrams-host = d.host;
        diagrams = pkgs.symlinkJoin {
          name = "diagrams-all";
          paths = [
            d.tailnet
            d.sshMatrix
            d.slurmSubmit
            d.topology
            d.network
            d.clusterAccess
            d.ownership
            d.host
          ];
        };
      };
    };
}
