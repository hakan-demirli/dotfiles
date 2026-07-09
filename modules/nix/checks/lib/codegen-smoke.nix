{ pkgs, self }:
let
  inherit (pkgs) lib;
  inventory = self.lib.inventory;
  p = self.packages.${pkgs.system};

  activeHostIds = lib.attrNames (
    lib.filterAttrs (
      _: h:
      !(builtins.elem h.state [
        "retired"
        "decommissioned"
      ])
    ) inventory.hosts
  );

  activeClusters = lib.filterAttrs (_: c: c.state != "retired") inventory.clusters;
  activeClusterIds = lib.attrNames activeClusters;
  clusterTagPairs = lib.filter (s: s != null) (
    lib.mapAttrsToList (
      cid: c:
      if (c.network.tailscale_tag or null) != null then "${cid}=${c.network.tailscale_tag}" else null
    ) activeClusters
  );

  activeUserIds = lib.attrNames (
    lib.filterAttrs (_: u: u.system_account != null && !(u.archived or false)) inventory.users
  );

  adminUserIds = lib.attrNames (lib.filterAttrs (_: u: u.cohort == "admin") inventory.users);

  adminAges = lib.unique (
    lib.concatLists (
      lib.mapAttrsToList (_: u: u.keys.age) (lib.filterAttrs (_: u: u.cohort == "admin") inventory.users)
    )
  );

  hostAgePairs = lib.mapAttrsToList (hid: ages: "${hid}=${lib.head ages}") (
    lib.filterAttrs (_: ages: ages != [ ]) (inventory.machineAge or { })
  );
in
pkgs.runCommand "codegen-smoke"
  {
    nativeBuildInputs = [ pkgs.jq ];
    inherit (p) kea matchbox;
    sopsYaml = p.sops-yaml;
    headscaleAcl = p.headscale-acl;
    diagramTailnet = p.diagrams-tailnet;
    diagramSshMatrix = p.diagrams-ssh-matrix;
    diagramSlurmSubmit = p.diagrams-slurm-submit;
    diagramNetwork = p.diagrams-network;
    diagramClusterAccess = p.diagrams-cluster-access;
    diagramOwnership = p.diagrams-ownership;
    diagramHost = p.diagrams-host;
    hostIds = lib.concatStringsSep " " activeHostIds;
    clusterIds = lib.concatStringsSep " " activeClusterIds;
    userIds = lib.concatStringsSep " " activeUserIds;
    adminIds = lib.concatStringsSep " " adminUserIds;
    adminAges = lib.concatStringsSep " " adminAges;
    hostAgePairs = lib.concatStringsSep " " hostAgePairs;
    clusterTagPairs = lib.concatStringsSep " " clusterTagPairs;
  }
  ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }
    pass() { echo "PASS: $*"; }

    test -f "$sopsYaml" || fail "sops-yaml output missing"

    for age in $adminAges; do
      grep -q "$age" "$sopsYaml" \
        || fail "sops-yaml: admin age recipient $age missing"
    done
    pass "sops-yaml: all admin recipients present ($(echo $adminAges | wc -w))"

    for h in $hostIds; do
      grep -q "secrets/hosts/$h" "$sopsYaml" \
        || fail "sops-yaml: missing per-host rule for $h"
    done
    pass "sops-yaml: per-host rules present for $(echo $hostIds | wc -w) hosts"

    for pair in $hostAgePairs; do
      hid="''${pair%=*}"
      age="''${pair#*=}"
      grep -q "$age" "$sopsYaml" \
        || fail "sops-yaml: host age recipient for $hid ($age) missing"
    done
    pass "sops-yaml: per-host age recipients present"

    for cid in $clusterIds; do
      grep -q "secrets/clusters/$cid" "$sopsYaml" \
        || fail "sops-yaml: missing per-cluster rule for $cid"
    done
    pass "sops-yaml: per-cluster rules present"

    grep -qF "secrets/system" "$sopsYaml" \
      || fail "sops-yaml: system.yaml rule missing"
    pass "sops-yaml: system.yaml rule present"

    test -f "$headscaleAcl/policy.hujson" || fail "headscale policy.hujson missing"
    body="$(grep -v '^//' "$headscaleAcl/policy.hujson" | grep -v '^$')"
    echo "$body" | jq -e . >/dev/null \
      || fail "headscale-acl: policy not valid JSON"
    pass "headscale-acl: valid JSON"

    if [ -n "$adminIds" ]; then
      echo "$body" | jq -e '.groups["group:admin"]' >/dev/null \
        || fail "headscale-acl: group:admin missing"
      for uid in $adminIds; do
        echo "$body" | jq -e --arg u "$uid" '.groups["group:admin"] | index($u)' >/dev/null \
          || fail "headscale-acl: admin $uid missing from group:admin"
      done
      pass "headscale-acl: group:admin contains all admins"
    fi

    for pair in $clusterTagPairs; do
      cid="''${pair%=*}"
      tag="''${pair#*=}"
      echo "$body" | jq -e --arg t "$tag" '.tagOwners[$t]' >/dev/null \
        || fail "headscale-acl: $tag missing for cluster $cid"
    done
    pass "headscale-acl: tags present for all clusters"

    test -e "$kea" || fail "kea missing"
    test -e "$matchbox" || fail "matchbox missing"
    pass "codegen: kea + matchbox built"

    for svg in \
      "$diagramTailnet/tailnet.svg" \
      "$diagramSshMatrix/ssh-matrix.svg" \
      "$diagramSlurmSubmit/slurm-submit.svg" \
      "$diagramNetwork/network-l3.svg" \
      "$diagramClusterAccess/cluster-access.svg" \
      "$diagramOwnership/ownership.svg"
    do
      test -f "$svg" || fail "diagram missing: $svg"
      grep -q '<svg' "$svg" || fail "no <svg root in $svg"
    done
    pass "diagrams: all fleet SVGs built"

    for cid in $clusterIds; do
      grep -q "cluster:$cid" "$diagramClusterAccess/cluster-access.dot" \
        || fail "cluster-access: cluster $cid missing"
    done
    pass "diagrams-cluster-access: all clusters rendered"

    for uid in $userIds; do
      grep -q "user:$uid" "$diagramClusterAccess/cluster-access.dot" \
        || fail "cluster-access: user $uid missing"
      grep -q "$uid" "$diagramSshMatrix/ssh-matrix.dot" \
        || fail "ssh-matrix: user $uid missing"
    done
    pass "diagrams: all users rendered in cluster-access + ssh-matrix"

    for h in $hostIds; do
      test -f "$diagramHost/hosts/$h.svg" \
        || fail "diagrams-host: $h.svg missing"
      grep -q '<svg' "$diagramHost/hosts/$h.svg" \
        || fail "diagrams-host: $h.svg empty"
    done
    pass "diagrams-host: per-host SVG for all $(echo $hostIds | wc -w) hosts"

    echo "all codegen smoke assertions passed" > "$out"
  ''
