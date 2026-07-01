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
        clusterRoles = diagrams.clusterRoles { inherit pkgs; };
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
        diagrams-cluster-roles = d.clusterRoles;
        diagrams-topology = d.topology;
        diagrams-network = d.network;
        diagrams-cluster-access = d.clusterAccess;
        diagrams-ownership = d.ownership;
        diagrams-host = d.host;
        diagrams =
          let
            parts = [
              d.tailnet
              d.sshMatrix
              d.slurmSubmit
              d.clusterRoles
              d.topology
              d.network
              d.clusterAccess
              d.ownership
              d.host
            ];
          in
          pkgs.runCommand "diagrams" { inherit parts; } ''
            mkdir -p $out/svg $out/dot
            for part in $parts; do
              for f in $(find "$part" -name '*.svg'); do
                rel="''${f#$part/}"
                mkdir -p "$out/svg/$(dirname "$rel")"
                cp "$f" "$out/svg/$rel"
              done
              for f in $(find "$part" -name '*.dot'); do
                rel="''${f#$part/}"
                mkdir -p "$out/dot/$(dirname "$rel")"
                cp "$f" "$out/dot/$rel"
              done
            done
          '';
      };
    };
}
