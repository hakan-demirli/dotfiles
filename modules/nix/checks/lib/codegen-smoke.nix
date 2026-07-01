{ pkgs, self }:
let
  p = self.packages.${pkgs.system};
  sopsYaml = p.sops-yaml;
  headscaleAcl = p.headscale-acl;
  inherit (p) kea matchbox;
  diagramsTailnet = p.diagrams-tailnet;
  diagramsSshMatrix = p.diagrams-ssh-matrix;
  diagramsSlurmSubmit = p.diagrams-slurm-submit;
  diagramsTopology = p.diagrams-topology;
  diagramsNetwork = p.diagrams-network;
  diagramsClusterAccess = p.diagrams-cluster-access;
  diagramsOwnership = p.diagrams-ownership;
  diagramsHost = p.diagrams-host;
in
pkgs.runCommand "codegen-smoke"
  {
    nativeBuildInputs = [ pkgs.jq ];
    inherit
      sopsYaml
      headscaleAcl
      kea
      matchbox
      diagramsTailnet
      diagramsSshMatrix
      diagramsSlurmSubmit
      diagramsTopology
      diagramsNetwork
      diagramsClusterAccess
      diagramsOwnership
      diagramsHost
      ;
  }
  ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }
    pass() { echo "PASS: $*"; }

    test -f "$sopsYaml" || fail "sops-yaml output is not a file"

    grep -q 'age14p6ttyxnqv7qh3nwpdcs5uflau4hy6edr6fj4c7kyexjz7yekyyqr5lgn2' "$sopsYaml" \
      || fail "sops-yaml: admin age recipient (user-0) missing from creation_rules"
    pass "sops-yaml: admin recipient present"

    for h in laptop-0 laptop-1 server-dev-0 server-dev-1 server-fpga-build-0 \
             server-fpga-dev-0 vps-oracle-0 vps-oracle-1; do
      grep -q "secrets/hosts/$h" "$sopsYaml" \
        || fail "sops-yaml: missing per-host rule for $h"
    done
    pass "sops-yaml: per-host rules present for all 8 nixos hosts"

    grep -q 'age150jk42s86el4wdr2w02heydgmqqu3gtuk4ypyxkwpftfmfcs94jqhzzuf4' "$sopsYaml" \
      || fail "sops-yaml: vps-oracle-0 host-level age recipient missing"
    pass "sops-yaml: vps-oracle-0 carries its host-level age key"

    for c in lab-fpga personal; do
      grep -q "secrets/clusters/$c" "$sopsYaml" \
        || fail "sops-yaml: missing per-cluster rule for explicit cluster $c"
    done
    pass "sops-yaml: per-cluster rules present for explicit clusters"

    grep -q "secrets/clusters/cluster-vps-oracle-1" "$sopsYaml" \
      || fail "sops-yaml: missing per-cluster rule for auto-implied cluster-vps-oracle-1"
    pass "sops-yaml: per-cluster rules cover auto-implied cluster-of-1"

    test -f "$headscaleAcl/policy.hujson" || fail "headscale-acl/policy.hujson missing"

    body="$(grep -v '^//' "$headscaleAcl/policy.hujson" | grep -v '^$')"
    echo "$body" | jq -e . >/dev/null || fail "headscale-acl: policy not valid JSON"
    pass "headscale-acl: policy is well-formed JSON"

    echo "$body" | jq -e '.groups["group:admin"]' >/dev/null \
      || fail "headscale-acl: synthetic group:admin missing"
    echo "$body" | jq -e '.groups["group:admin"] | index("user-0")' >/dev/null \
      || fail "headscale-acl: user-0 not in group:admin"
    pass "headscale-acl: group:admin contains user-0"

    echo "$body" | jq -e '.tagOwners["tag:cluster-lab-fpga"]' >/dev/null \
      || fail "headscale-acl: broad lab-fpga tag missing"
    echo "$body" | jq -e '.tagOwners["tag:cluster-lab-fpga-compute"]' >/dev/null \
      || fail "headscale-acl: lab-fpga compute sub-tag missing"
    pass "headscale-acl: lab-fpga gets both broad + -compute sub-tag"

    echo "$body" | jq -e \
      '.acls[] | select(.src == ["group:admin"]) | .dst | index("tag:cluster-lab-fpga:*")' \
      >/dev/null || fail "headscale-acl: admin rule missing lab-fpga"
    echo "$body" | jq -e \
      '.acls[] | select(.src == ["group:admin"]) | .dst | index("tag:cluster-personal:*")' \
      >/dev/null || fail "headscale-acl: admin rule missing personal"
    pass "headscale-acl: admin rule reaches every cluster"

    echo "$body" | jq -e \
      '.acls[] | select(.src == ["tag:cluster-lab-fpga-compute"]) | .dst | index("tag:cluster-lab-fpga-compute:*")' \
      >/dev/null || fail "headscale-acl: lab-fpga compute mesh missing"
    pass "headscale-acl: compute<->compute mesh present"

    test -e "$kea" || fail "kea derivation produced no output"
    test -e "$matchbox" || fail "matchbox derivation produced no output"
    pass "kea, matchbox: build clean"

    test -f "$diagramsTailnet/tailnet.svg" \
      || fail "diagrams-tailnet: tailnet.svg missing"
    grep -q '<svg' "$diagramsTailnet/tailnet.svg" \
      || fail "diagrams-tailnet: no <svg root"
    grep -q 'ADMINS REACH' "$diagramsTailnet/tailnet.svg" \
      || fail "diagrams-tailnet: 'ADMINS REACH' chip missing from SVG"
    grep -q '>personal' "$diagramsTailnet/tailnet.svg" \
      || fail "diagrams-tailnet: 'personal' cluster missing from SVG"
    pass "diagrams-tailnet: SVG built with admin chip + clusters"

    test -f "$diagramsSshMatrix/ssh-matrix.svg" \
      || fail "diagrams-ssh-matrix: ssh-matrix.svg missing"
    grep -q '<svg' "$diagramsSshMatrix/ssh-matrix.svg" \
      || fail "diagrams-ssh-matrix: no <svg root"
    grep -q 'SSH access matrix' "$diagramsSshMatrix/ssh-matrix.svg" \
      || fail "diagrams-ssh-matrix: title missing"
    grep -q '>user-0' "$diagramsSshMatrix/ssh-matrix.svg" \
      || fail "diagrams-ssh-matrix: user-0 row missing"
    pass "diagrams-ssh-matrix: SVG built with title + user-0 row"

    test -f "$diagramsSlurmSubmit/slurm-submit.svg" \
      || fail "diagrams-slurm-submit: slurm-submit.svg missing"
    grep -q '<svg' "$diagramsSlurmSubmit/slurm-submit.svg" \
      || fail "diagrams-slurm-submit: no <svg root"
    grep -q 'personal' "$diagramsSlurmSubmit/slurm-submit.svg" \
      || fail "diagrams-slurm-submit: personal cluster title missing"
    grep -q 'lab-fpga' "$diagramsSlurmSubmit/slurm-submit.svg" \
      || fail "diagrams-slurm-submit: lab-fpga cluster title missing"
    grep -q 'slurmctld' "$diagramsSlurmSubmit/slurm-submit.svg" \
      || fail "diagrams-slurm-submit: slurmctld row label missing"
    pass "diagrams-slurm-submit: SVG built with personal + lab-fpga + slurmctld"

    test -f "$diagramsTopology/topology-lab-leaf-mesh.svg" \
      || fail "diagrams-topology: lab-leaf-mesh.svg missing"
    grep -q '<svg' "$diagramsTopology/topology-lab-leaf-mesh.svg" \
      || fail "diagrams-topology: lab-leaf-mesh.svg has no <svg root"
    grep -q 'sw-be10000-0' "$diagramsTopology/topology-lab-leaf-mesh.dot" \
      || fail "diagrams-topology: sw-be10000-0 missing from dot source"
    grep -q 'sw-be10000-1' "$diagramsTopology/topology-lab-leaf-mesh.dot" \
      || fail "diagrams-topology: sw-be10000-1 missing from dot source"
    pass "diagrams-topology: lab-leaf-mesh SVG built with both leaves"

    test -f "$diagramsNetwork/network-l3.svg" \
      || fail "diagrams-network: network-l3.svg missing"
    grep -q '<svg' "$diagramsNetwork/network-l3.svg" \
      || fail "diagrams-network: network-l3.svg has no <svg root"
    for n in data fpga-storage mgmt-bmc; do
      grep -q "net:$n" "$diagramsNetwork/network-l3.dot" \
        || fail "diagrams-network: network '$n' missing from dot source"
    done
    pass "diagrams-network: all 3 networks present"

    test -f "$diagramsClusterAccess/cluster-access.svg" \
      || fail "diagrams-cluster-access: cluster-access.svg missing"
    grep -q '<svg' "$diagramsClusterAccess/cluster-access.svg" \
      || fail "diagrams-cluster-access: no <svg root"
    grep -q 'cluster:lab-fpga' "$diagramsClusterAccess/cluster-access.dot" \
      || fail "diagrams-cluster-access: lab-fpga cluster missing"
    grep -q 'cluster:personal' "$diagramsClusterAccess/cluster-access.dot" \
      || fail "diagrams-cluster-access: personal cluster missing"
    grep -q 'team:team-research' "$diagramsClusterAccess/cluster-access.dot" \
      || fail "diagrams-cluster-access: team-research missing"
    grep -q 'user:user-0' "$diagramsClusterAccess/cluster-access.dot" \
      || fail "diagrams-cluster-access: user-0 missing"
    pass "diagrams-cluster-access: users, teams, clusters all present"

    test -f "$diagramsOwnership/ownership.svg" \
      || fail "diagrams-ownership: ownership.svg missing"
    grep -q '<svg' "$diagramsOwnership/ownership.svg" \
      || fail "diagrams-ownership: no <svg root"
    grep -q 'cluster_class_personal' "$diagramsOwnership/ownership.dot" \
      || fail "diagrams-ownership: 'personal' class subgraph missing"
    grep -q 'cluster_class_company' "$diagramsOwnership/ownership.dot" \
      || fail "diagrams-ownership: 'company' class subgraph missing"
    grep -q 'a:switch:sw-be10000-0' "$diagramsOwnership/ownership.dot" \
      || fail "diagrams-ownership: switch sw-be10000-0 missing"
    pass "diagrams-ownership: class subgraphs + switches present"

    for h in laptop-0 laptop-1 server-dev-0 server-dev-1 server-fpga-build-0 \
             server-fpga-dev-0 vps-oracle-0 vps-oracle-1; do
      test -f "$diagramsHost/hosts/$h.svg" \
        || fail "diagrams-host: $h.svg missing"
      grep -q '<svg' "$diagramsHost/hosts/$h.svg" \
        || fail "diagrams-host: $h.svg has no <svg root"
    done
    pass "diagrams-host: per-host SVG built for all 8 nixos hosts"

    echo "" > "$out"
    echo "all codegen smoke assertions passed" >> "$out"
  ''
