{
  pkgs,
  self,
  inputs,
}:
let
  inherit (pkgs) lib;
  inherit (inputs.infra-lib.lib) headscalePolicy;
  inventory = self.lib.inventory;
  intent = self.lib.intent;
  p = self.packages.${pkgs.stdenv.hostPlatform.system};
  isActiveUser = uid: inventory.users ? ${uid} && !(inventory.users.${uid}.archived or false);

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
  secretClusterIds = lib.attrNames (
    lib.filterAttrs (_: c: (c.secret_paths or { }) != { }) activeClusters
  );
  clusterTagPairs = lib.filter (s: s != null) (
    lib.mapAttrsToList (
      cid: c:
      if (c.network.tailscale_tag or null) != null then "${cid}=${c.network.tailscale_tag}" else null
    ) activeClusters
  );

  activeUserIds = lib.attrNames (
    lib.filterAttrs (_: u: u.system_account != null && !(u.archived or false)) inventory.users
  );

  tailnetAdminUserIds = map headscaleId (
    lib.attrNames (
      lib.filterAttrs (_: u: lib.elem "tailnet" u.admin_scopes && !(u.archived or false)) inventory.users
    )
  );

  headscaleId =
    uid:
    let
      configured = inventory.users.${uid}.headscale_user or null;
      username = if configured == null then uid else configured;
    in
    headscalePolicy.userPrincipal username;

  stripTag = tag: lib.removePrefix "tag:" tag;
  baseTag =
    cid:
    let
      configured = activeClusters.${cid}.network.tailscale_tag or null;
    in
    if configured != null then stripTag configured else "cluster-${cid}";
  broadTag = cid: "tag:${baseTag cid}";
  loginTag =
    cid:
    if (inventory.loginNodesOfCluster.${cid} or [ ]) != [ ] then
      "tag:${baseTag cid}-login"
    else
      broadTag cid;

  grantedTeamIds = lib.unique (
    lib.concatMap (cluster: map (grant: grant.team) cluster.access.teams) (
      lib.attrValues activeClusters
    )
  );
  teamMemberPairs = lib.concatMap (
    tid:
    map (member: "${tid}=${headscaleId member.user}") (
      lib.filter (member: isActiveUser member.user) inventory.teams.${tid}.members
    )
  ) grantedTeamIds;
  teamAclPairs = lib.concatMap (
    cid: map (grant: "group:${grant.team}=${loginTag cid}:*") activeClusters.${cid}.access.teams
  ) activeClusterIds;
  userAclPairs = lib.concatMap (
    cid:
    map (grant: "${headscaleId grant.user}=${loginTag cid}:*") (
      lib.filter (grant: isActiveUser grant.user) activeClusters.${cid}.access.users
    )
  ) activeClusterIds;
  adminAclDestinations = (map (cid: "${broadTag cid}:*") activeClusterIds) ++ [ "tag:bootstrap:*" ];
  fleetAdminTag = "tag:fleet-admin-client";
  metricsTag = "tag:metrics";
  nixCacheTag = "tag:nix-binary-cache";
  controllerTags = map (cid: "tag:${baseTag cid}-controller") (
    lib.filter (cid: (inventory.controllerNodesOfCluster.${cid} or [ ]) != [ ]) activeClusterIds
  );

  fleetAdminAges = lib.unique (
    lib.concatLists (
      lib.mapAttrsToList (_: u: u.keys.age) (
        lib.filterAttrs (_: u: lib.elem "fleet" u.admin_scopes && !(u.archived or false)) inventory.users
      )
    )
  );

  hostAgePairs = lib.mapAttrsToList (hid: ages: "${hid}=${lib.head ages}") (
    lib.filterAttrs (_: ages: ages != [ ]) (inventory.machineAge or { })
  );
in
assert
  intent.hostPolicyTags."laptop-1" == [
    fleetAdminTag
    metricsTag
    nixCacheTag
  ];
assert
  intent.hostPolicyTags."router-0" == [
    "tag:cluster-router-0"
    metricsTag
  ];
assert intent.canHostReach "laptop-1" "vps-oracle-0" "22";
assert intent.canHostReach "vps-oracle-0" "laptop-1" "9100";
assert intent.canHostReach "vps-oracle-0" "laptop-1" "9633";
assert intent.canHostReach "vps-oracle-0" "router-0" "9100";
assert intent.canHostReach "laptop-0" "vps-oracle-0" "9428";
assert intent.canHostReach "laptop-0" "vps-oracle-0" "5101";
assert intent.canHostReach "server-dev-1" "laptop-1" "873";
assert !(intent.canHostReach "vps-oracle-0" "laptop-1" "22");
assert !(intent.canHostReach "vps-oracle-0" "router-0" "22");
assert !(intent.canHostReach "laptop-0" "vps-oracle-0" "22");
assert !(intent.canHostReach "laptop-0" "laptop-1" "22");
assert !(intent.canHostReach "router-0" "vps-oracle-0" "9428");
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
    secretClusterIds = lib.concatStringsSep " " secretClusterIds;
    userIds = lib.concatStringsSep " " activeUserIds;
    tailnetAdminIds = lib.concatStringsSep " " tailnetAdminUserIds;
    fleetAdminAges = lib.concatStringsSep " " fleetAdminAges;
    hostAgePairs = lib.concatStringsSep " " hostAgePairs;
    clusterTagPairs = lib.concatStringsSep " " clusterTagPairs;
    teamMemberPairs = lib.concatStringsSep " " teamMemberPairs;
    teamAclPairs = lib.concatStringsSep " " teamAclPairs;
    userAclPairs = lib.concatStringsSep " " userAclPairs;
    adminAclDestinations = lib.concatStringsSep " " adminAclDestinations;
    controllerTags = lib.concatStringsSep " " controllerTags;
    inherit fleetAdminTag metricsTag nixCacheTag;
  }
  ''
    set -euo pipefail
    fail() { echo "FAIL: $*" >&2; exit 1; }
    pass() { echo "PASS: $*"; }

    test -f "$sopsYaml" || fail "sops-yaml output missing"

    for age in $fleetAdminAges; do
      grep -q "$age" "$sopsYaml" \
        || fail "sops-yaml: fleet-admin age recipient $age missing"
    done
    pass "sops-yaml: all fleet-admin recipients present ($(echo $fleetAdminAges | wc -w))"

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

    for cid in $secretClusterIds; do
      grep -q "secrets/clusters/$cid" "$sopsYaml" \
        || fail "sops-yaml: missing per-cluster rule for $cid"
    done
    pass "sops-yaml: declared per-cluster secret rules present"

    grep -qF "secrets/system" "$sopsYaml" \
      || fail "sops-yaml: system.yaml rule missing"
    pass "sops-yaml: system.yaml rule present"

    test -f "$headscaleAcl/policy.hujson" || fail "headscale policy.hujson missing"
    body="$(grep -v '^//' "$headscaleAcl/policy.hujson" | grep -v '^$')"
    echo "$body" | jq -e . >/dev/null \
      || fail "headscale-acl: policy not valid JSON"
    pass "headscale-acl: valid JSON"

    echo "$body" | jq -e \
      '[.groups[]?[] | select(test("^[^@]+@[^@]*$") | not)] | length == 0' >/dev/null \
      || fail "headscale-acl: group contains an invalid user principal"
    pass "headscale-acl: group user principals are canonical"

    if [ -n "$tailnetAdminIds" ]; then
      echo "$body" | jq -e '.groups["group:admin"]' >/dev/null \
        || fail "headscale-acl: group:admin missing"
      for uid in $tailnetAdminIds; do
        echo "$body" | jq -e --arg u "$uid" '.groups["group:admin"] | index($u)' >/dev/null \
          || fail "headscale-acl: admin $uid missing from group:admin"
      done
      pass "headscale-acl: group:admin contains all Tailnet admins"
    fi

    for pair in $teamMemberPairs; do
      team="''${pair%=*}"
      user="''${pair#*=}"
      echo "$body" | jq -e --arg group "group:$team" --arg user "$user" \
        '.groups[$group] | index($user) != null' >/dev/null \
        || fail "headscale-acl: $user missing from group:$team"
    done
    pass "headscale-acl: actual team memberships present"

    for pair in $teamAclPairs $userAclPairs; do
      src="''${pair%=*}"
      dst="''${pair#*=}"
      echo "$body" | jq -e --arg src "$src" --arg dst "$dst" \
        '.acls | any(.action == "accept" and ((.src | index($src)) != null) and ((.dst | index($dst)) != null))' >/dev/null \
        || fail "headscale-acl: missing inventory grant $src -> $dst"
    done
    pass "headscale-acl: actual inventory grants present"

    for dst in $adminAclDestinations; do
      echo "$body" | jq -e --arg dst "$dst" \
        --arg src "$fleetAdminTag" \
        '.acls | any(.action == "accept" and ((.src | index($src)) != null) and ((.dst | index($dst)) != null))' >/dev/null \
        || fail "headscale-acl: $fleetAdminTag missing access to $dst"
    done
    pass "headscale-acl: fleet admin client reachability present"

    echo "$body" | jq -e --arg tag "$fleetAdminTag" \
      '.tagOwners[$tag] == ["group:admin"]' >/dev/null \
      || fail "headscale-acl: fleet admin tag ownership missing"

    echo "$body" | jq -e --arg tag "$metricsTag" \
      '.tagOwners[$tag] == ["group:admin"]' >/dev/null \
      || fail "headscale-acl: metrics tag ownership missing"

    echo "$body" | jq -e --arg tag "$nixCacheTag" \
      '.tagOwners[$tag] == ["group:admin"]' >/dev/null \
      || fail "headscale-acl: nix binary cache tag ownership missing"

    echo "$body" | jq -e \
      '.acls | all((.src | index("group:admin")) == null)' >/dev/null \
      || fail "headscale-acl: broad group:admin ACL still present"

    for src in $controllerTags; do
      for port in 9100 9633; do
        echo "$body" | jq -e --arg src "$src" --arg dst "$metricsTag:$port" \
          '.acls | any(.action == "accept" and ((.src | index($src)) != null) and ((.dst | index($dst)) != null))' >/dev/null \
          || fail "headscale-acl: missing monitoring path $src -> $dst"
      done
    done
    pass "headscale-acl: controller monitoring paths present"

    for pair in $clusterTagPairs; do
      cid="''${pair%=*}"
      tag="''${pair#*=}"
      echo "$body" | jq -e --arg t "$tag" '.tagOwners[$t]' >/dev/null \
        || fail "headscale-acl: $tag missing for cluster $cid"
    done
    pass "headscale-acl: tags present for all clusters"

    grep -q "$fleetAdminTag" "$diagramTailnet/tailnet.dot" \
      || fail "tailnet diagram: fleet admin tag missing"

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
