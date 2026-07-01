{
  lib,
  inventory,
  intent,
}:
with lib;
let
  inherit (inventory)
    hosts
    switches
    networks
    topologies
    teams
    clusters
    users
    roles
    hostToCluster
    hostsByCluster
    hostNodeRoles
    ;

  q = s: replaceStrings [ "\"" ] [ "\\\"" ] (toString s);

  xml = s: replaceStrings [ "&" "<" ">" "\"" ] [ "&amp;" "&lt;" "&gt;" "&quot;" ] (toString s);

  i = s: "\"${q s}\"";

  orNull = v: fallback: if v == null then fallback else v;

  firstNonNull =
    vs: fallback:
    let
      good = filter (v: v != null) vs;
    in
    if good == [ ] then fallback else head good;

  lbl = lines: concatStringsSep "\\n" (map q (filter (l: l != null) lines));

  sortedAttrNames = attrs: sort lessThan (attrNames attrs);

  palette = {
    switch = "#dbeafe";
    host = "#dcfce7";
    hostPlanned = "#fef9c3";
    hostRetired = "#fecaca";
    network = "#fef3c7";
    user = "#fce7f3";
    team = "#f3e8ff";
    cluster = "#e2e8f0";
    site = "#ffedd5";
    rack = "#f3f4f6";
    external = "#ffffff";
    edgeUplink = "#1d4ed8";
    edgeDownlink = "#15803d";
    edgeMlag = "#b91c1c";
    edgeMgmt = "#6b21a8";
    edgeDefault = "#374151";
  };

  hostFill =
    h:
    if h.state == "retired" then
      palette.hostRetired
    else if h.state == "planned" then
      palette.hostPlanned
    else
      palette.host;

  portEdgeColor =
    role:
    {
      uplink = palette.edgeUplink;
      downlink-host = palette.edgeDownlink;
      downlink-switch = palette.edgeDownlink;
      mlag-peer = palette.edgeMlag;
      mgmt = palette.edgeMgmt;
      oob = palette.edgeMgmt;
    }
    .${role} or palette.edgeDefault;

  topologyDot =
    topo:
    let
      declared = unique (topo.spines ++ topo.leaves ++ topo.edge);
      ports =
        sid:
        let
          s = switches.${sid} or null;
        in
        if s == null then [ ] else (mapAttrsToList (_: p: p // { switch = sid; }) s.ports);
      allPorts = concatLists (map ports declared);

      isHost = n: hosts ? ${n};
      isSwitch = n: switches ? ${n};
      isExternal = n: !(isHost n) && !(isSwitch n);

      peerNodes = unique (filter (n: n != null) (map (p: p.peer) allPorts));

      switchNode =
        sid:
        let
          s = switches.${sid};
          vendor = s.hardware.vendor;
          model = s.hardware.model;
          label = lbl [
            sid
            "${vendor} ${model}"
            "role=${s.role} state=${s.state}"
          ];
        in
        "    ${i sid} [label=\"${label}\", shape=box, style=\"filled,rounded\", fillcolor=\"${palette.switch}\"];";

      hostNode =
        hid:
        let
          h = hosts.${hid};
          label = lbl [
            hid
            "roles=${concatStringsSep "," h.roles}"
          ];
        in
        "  ${i hid} [label=\"${label}\", shape=box, style=filled, fillcolor=\"${hostFill h}\"];";

      externalNode =
        n: "  ${i n} [label=\"${q n}\", shape=ellipse, style=dashed, fillcolor=\"${palette.external}\"];";

      pairKey =
        p:
        let
          ends = sort lessThan [
            p.switch
            p.peer
          ];
        in
        "${head ends}::${elemAt ends 1}";

      portsWithPeer = filter (p: p.peer != null) allPorts;

      dedup =
        foldl'
          (
            acc: p:
            let
              k = pairKey p;
              isSwSw = isSwitch p.peer;
            in
            if isSwSw && acc.seen ? ${k} then
              acc
            else
              {
                seen = acc.seen // {
                  ${k} = true;
                };
                out = acc.out ++ [ p ];
              }
          )
          {
            seen = { };
            out = [ ];
          }
          portsWithPeer;

      portEdge =
        p:
        let
          speed = if p.speed_gbps == null then "" else "${toString p.speed_gbps}G ";
          label = lbl [
            "${speed}${p.role}"
            "${p.switch}:${p.name}${if p.peer_port == null then "" else " <-> ${p.peer}:${p.peer_port}"}"
          ];
          color = portEdgeColor p.role;
        in
        "  ${i p.switch} -- ${i p.peer} [label=\"${label}\", color=\"${color}\", fontsize=9];";

      groupBlock =
        cls: ids:
        let
          inside = concatStringsSep "\n" (map switchNode ids);
        in
        if ids == [ ] then
          ""
        else
          ''
            subgraph "cluster_${cls}" {
              label="${cls}"; style="rounded,filled"; fillcolor="${palette.cluster}";
            ${inside}
            }'';

      spineBlock = groupBlock "spines" topo.spines;
      leafBlock = groupBlock "leaves" topo.leaves;
      edgeBlock = groupBlock "edge" topo.edge;
      otherSwitches = filter (
        sid: !(elem sid topo.spines) && !(elem sid topo.leaves) && !(elem sid topo.edge)
      ) (filter isSwitch peerNodes);
      otherBlock = groupBlock "other-switches" otherSwitches;

      hostBlock = concatStringsSep "\n" (map hostNode (filter isHost peerNodes));
      extBlock = concatStringsSep "\n" (map externalNode (filter isExternal peerNodes));
      edges = concatStringsSep "\n" (map portEdge dedup.out);

    in
    ''
      graph "topology_${topo.id}" {
        labelloc="t"; fontsize=18;
        label="Topology: ${topo.id}\n${topo.kind}\n${topo.description}";
        rankdir=TB; splines=true; overlap=false;
        node [fontname="Helvetica"]; edge [fontname="Helvetica"];

      ${spineBlock}
      ${leafBlock}
      ${edgeBlock}
      ${otherBlock}
      ${hostBlock}
      ${extBlock}
      ${edges}
      }
    '';

  networkDot =
    let
      netNode =
        n:
        let
          netId = n.id;
          fields = [
            (n.prefix_v4 or null)
            (n.prefix_v6 or null)
            (if n.vlan_id == null then null else "VLAN ${toString n.vlan_id}")
            (if n.vrf == null then null else "VRF ${n.vrf}")
            (if n.bgp_asn == null then null else "ASN ${toString n.bgp_asn}")
            "qos=${n.qos_class}"
          ];
          label = lbl ([ netId ] ++ filter (x: x != null) fields);
        in
        "  ${i "net:${netId}"} [label=\"${label}\", shape=ellipse, style=filled, fillcolor=\"${palette.network}\"];";

      hostNicEdges =
        hid: h:
        let
          attached = filter (n: networks ? ${n.network}) h.nics;
          mkEdge =
            nic:
            let
              ipPart = if nic.ipv4 == null then "" else " ${nic.ipv4}";
            in
            "  ${i hid} -- ${i "net:${nic.network}"} [label=\"${q nic.name}\\n${q nic.role}${q ipPart}\", fontsize=9];";
        in
        map mkEdge attached;

      bmcEdges =
        hid: h:
        if h.bmc == null then
          [ ]
        else
          [
            "  ${i hid} -- ${i "net:${h.bmc.network}"} [label=\"bmc/${q h.bmc.vendor}\", style=dashed, fontsize=9, color=\"${palette.edgeMgmt}\"];"
          ];

      switchMgmtEdges =
        sid: s:
        if s.mgmt_network == null then
          [ ]
        else
          [
            "  ${i "sw:${sid}"} -- ${i "net:${s.mgmt_network}"} [label=\"mgmt\", style=dashed, fontsize=9, color=\"${palette.edgeMgmt}\"];"
          ];

      hostNode =
        hid: h:
        let
          label = lbl [
            hid
            (concatStringsSep "," h.roles)
          ];
        in
        "  ${i hid} [label=\"${label}\", shape=box, style=filled, fillcolor=\"${hostFill h}\"];";

      switchNode =
        sid: s:
        let
          label = lbl [
            sid
            "${s.hardware.vendor} ${s.hardware.model}"
            (if s.mgmt_ipv4 == null then null else "mgmt ${s.mgmt_ipv4}")
            (if s.bgp == null then null else "ASN ${toString s.bgp.asn}")
          ];
        in
        "  ${i "sw:${sid}"} [label=\"${label}\", shape=box, style=\"filled,rounded\", fillcolor=\"${palette.switch}\"];";

      netBlock = concatStringsSep "\n" (mapAttrsToList (_: netNode) networks);
      hostBlock = concatStringsSep "\n" (mapAttrsToList hostNode hosts);
      swBlock = concatStringsSep "\n" (mapAttrsToList switchNode switches);
      hostEdgeBlock = concatStringsSep "\n" (concatLists (mapAttrsToList hostNicEdges hosts));
      bmcEdgeBlock = concatStringsSep "\n" (concatLists (mapAttrsToList bmcEdges hosts));
      swEdgeBlock = concatStringsSep "\n" (concatLists (mapAttrsToList switchMgmtEdges switches));
    in
    ''
      graph "network_l3" {
        labelloc="t"; fontsize=18; label="Networks / L3 attachments";
        rankdir=LR; splines=true; overlap=false;
        node [fontname="Helvetica"]; edge [fontname="Helvetica"];

      ${netBlock}
      ${hostBlock}
      ${swBlock}
      ${hostEdgeBlock}
      ${bmcEdgeBlock}
      ${swEdgeBlock}
      }
    '';

  activeClusters = filterAttrs (_: c: c.state != "retired") clusters;

  tierLabel =
    t: if isString t then t else concatStringsSep "," (mapAttrsToList (k: v: "${k}=${v}") t);

  clustersBySize =
    let
      sizeOf = cid: length (hostsByCluster.${cid} or [ ]);
    in
    sort (
      a: b:
      let
        la = sizeOf a;
        lb = sizeOf b;
      in
      if la != lb then la > lb else a < b
    ) (attrNames activeClusters);

  fleetPalette = [
    {
      fill = "#bfdbfe";
      border = "#1d4ed8";
    }
    {
      fill = "#bbf7d0";
      border = "#15803d";
    }
    {
      fill = "#fed7aa";
      border = "#c2410c";
    }
    {
      fill = "#ddd6fe";
      border = "#6d28d9";
    }
    {
      fill = "#fef08a";
      border = "#a16207";
    }
    {
      fill = "#fbcfe8";
      border = "#be185d";
    }
    {
      fill = "#a7f3d0";
      border = "#047857";
    }
    {
      fill = "#fda4af";
      border = "#be123c";
    }
  ];

  paletteAt = idx: elemAt fleetPalette (mod idx (length fleetPalette));

  multiHostClusters = filter (cid: length (hostsByCluster.${cid} or [ ]) > 1) clustersBySize;

  fleetColors = listToAttrs (imap0 (i: cid: nameValuePair cid (paletteAt i)) multiHostClusters);

  fleetSoloColor = {
    fill = "#f1f5f9";
    border = "#94a3b8";
  };

  fleetColorFor = cid: fleetColors.${cid} or fleetSoloColor;

  hostShapeFor =
    hid:
    let
      nrs = hostNodeRoles.${hid} or [ "personal" ];
    in
    if elem "controller" nrs then
      "doublecircle"
    else if elem "mgmt" nrs then
      "cylinder"
    else if elem "compute" nrs then
      "box3d"
    else if elem "login" nrs then
      "house"
    else if elem "external" nrs then
      "note"
    else
      "box";

  hostStyleFor = hid: if hostShapeFor hid == "box" then "filled,rounded" else "filled";

  clusterAccessDot =
    let
      teamMembers = tid: if teams ? ${tid} then map (m: m.user) teams.${tid}.members else [ ];

      teamsUsed = unique (
        concatLists (mapAttrsToList (_: c: map (g: g.team) c.access.teams) activeClusters)
      );
      usersUsed = unique (
        concatLists (map teamMembers teamsUsed)
        ++ concatLists (mapAttrsToList (_: c: map (g: g.user) c.access.users) activeClusters)
      );

      userNode =
        uid:
        let
          u = users.${uid} or null;
          username = if u == null then uid else (u.system_account.username or uid);
          cohort = if u == null then "?" else u.cohort;
          label = lbl [
            uid
            "user: ${username}"
            "cohort: ${cohort}"
          ];
        in
        "  ${i "user:${uid}"} [label=\"${label}\", shape=box, style=\"filled,rounded\", fillcolor=\"${palette.user}\"];";

      teamNode =
        tid:
        let
          t = teams.${tid} or null;
          mcount = if t == null then 0 else length t.members;
          synth = if t != null && (t.labels.synthesised or "") == "true" then " (auto)" else "";
          label = lbl [
            tid
            "members: ${toString mcount}${synth}"
          ];
        in
        "  ${i "team:${tid}"} [label=\"${label}\", shape=box, style=\"filled,rounded\", fillcolor=\"${palette.team}\"];";

      clusterNode =
        cid:
        let
          c = clusters.${cid};
          synth = if c.synthesised then " (auto)" else "";
          sched = c.scheduler.kind;
          numHosts = length (hostsByCluster.${cid} or [ ]);
          col = fleetColorFor cid;
          width = toString (1.0 + 0.35 * numHosts);
          label = lbl [
            "${cid}  [${toString numHosts} hosts]"
            "kind=${c.kind} state=${c.state}${synth}"
            "scheduler=${sched}"
          ];
        in
        "  ${i "cluster:${cid}"} [label=\"${label}\", shape=box, style=\"filled,rounded\","
        + " width=${width}, height=0.7,"
        + " fillcolor=\"${col.fill}\", color=\"${col.border}\", penwidth=2,"
        + " fontsize=11];";

      hostNode =
        hid:
        let
          h = hosts.${hid};
          cid = hostToCluster.${hid} or null;
          col = if cid == null then fleetSoloColor else fleetColorFor cid;
          label = lbl [
            hid
            (concatStringsSep "," h.roles)
            h.hardware.arch
          ];
        in
        "  ${i "host:${hid}"} [label=\"${label}\", shape=${hostShapeFor hid},"
        + " style=\"${hostStyleFor hid}\","
        + " fillcolor=\"${col.fill}\", color=\"${col.border}\", penwidth=1.5,"
        + " fontsize=10];";

      teamMemberEdges =
        tid:
        let
          t = teams.${tid} or null;
        in
        if t == null then
          [ ]
        else
          map (
            m: "  ${i "user:${m.user}"} -> ${i "team:${tid}"} [label=\"${q m.role}\", fontsize=9];"
          ) t.members;

      teamClusterEdges =
        cid:
        let
          c = activeClusters.${cid};
        in
        map (
          g:
          "  ${i "team:${g.team}"} -> ${i "cluster:${cid}"} [label=\"${q (tierLabel g.tier)}\", color=\"${palette.edgeUplink}\", fontsize=9];"
        ) c.access.teams;

      userClusterEdges =
        cid:
        let
          c = activeClusters.${cid};
        in
        map (
          g:
          "  ${i "user:${g.user}"} -> ${i "cluster:${cid}"} [label=\"${q g.tier}\", color=\"${palette.edgeMlag}\", style=dashed, fontsize=9];"
        ) c.access.users;

      clusterHostEdges =
        cid:
        let
          hs = hostsByCluster.${cid} or [ ];
        in
        map (
          hid:
          "  ${i "cluster:${cid}"} -> ${i "host:${hid}"} [color=\"${palette.edgeDownlink}\", arrowhead=none];"
        ) hs;

      hostsInClusterOrder = concatMap (cid: sort lessThan (hostsByCluster.${cid} or [ ])) clustersBySize;

      userBlock = concatStringsSep "\n" (map userNode (sort lessThan usersUsed));
      teamBlock = concatStringsSep "\n" (map teamNode (sort lessThan teamsUsed));
      clusterBlock = concatStringsSep "\n" (map clusterNode clustersBySize);
      hostBlock = concatStringsSep "\n" (map hostNode hostsInClusterOrder);

      memberEdgeBlock = concatStringsSep "\n" (concatLists (map teamMemberEdges teamsUsed));
      teamClusterBlock = concatStringsSep "\n" (
        concatLists (map teamClusterEdges (attrNames activeClusters))
      );
      userClusterBlock = concatStringsSep "\n" (
        concatLists (map userClusterEdges (attrNames activeClusters))
      );
      clusterHostBlock = concatStringsSep "\n" (
        concatLists (map clusterHostEdges (attrNames activeClusters))
      );
    in
    ''
      digraph "cluster_access" {
        labelloc="t"; fontsize=18;
        label="Cluster access: users -> teams -> clusters -> hosts";
        rankdir=LR; splines=true; concentrate=true; overlap=false;
        node [fontname="Helvetica"]; edge [fontname="Helvetica"];

        subgraph "cluster_users"    { label="users";    style="rounded,filled"; fillcolor="#fff7fb";
      ${userBlock}
        }
        subgraph "cluster_teams"    { label="teams";    style="rounded,filled"; fillcolor="#faf5ff";
      ${teamBlock}
        }
        subgraph "cluster_clusters" { label="clusters"; style="rounded,filled"; fillcolor="#f1f5f9";
      ${clusterBlock}
        }
        subgraph "cluster_hosts"    { label="hosts";    style="rounded,filled"; fillcolor="#f0fdf4";
      ${hostBlock}
        }

      ${memberEdgeBlock}
      ${teamClusterBlock}
      ${userClusterBlock}
      ${clusterHostBlock}
      }
    '';

  ownershipDot =
    let
      assets =
        (mapAttrsToList (id: h: {
          kind = "host";
          inherit id;
          entity = h;
        }) hosts)
        ++ (mapAttrsToList (id: s: {
          kind = "switch";
          inherit id;
          entity = s;
        }) switches);

      assetsByClass = foldl' (
        acc: a:
        let
          c = a.entity.ownership.class;
        in
        acc // { ${c} = (acc.${c} or [ ]) ++ [ a ]; }
      ) { } assets;

      principalsReferenced =
        let
          fromAsset =
            a:
            filter (x: x != null) [
              a.entity.ownership.owner
              a.entity.ownership.team
              (a.entity.ownership.operator or null)
              (a.entity.ownership.custodian or null)
            ];
          allRefs = concatLists (map fromAsset assets);
        in
        unique allRefs;

      principalNode =
        pid:
        if users ? ${pid} then
          let
            u = users.${pid};
            label = lbl [
              pid
              "user (${u.cohort})"
            ];
          in
          "  ${i "p:${pid}"} [label=\"${label}\", shape=box, style=\"filled,rounded\", fillcolor=\"${palette.user}\"];"
        else if teams ? ${pid} then
          let
            t = teams.${pid};
            label = lbl [
              pid
              "team"
              "members: ${toString (length t.members)}"
            ];
          in
          "  ${i "p:${pid}"} [label=\"${label}\", shape=box, style=\"filled,rounded\", fillcolor=\"${palette.team}\"];"
        else
          "  ${i "p:${pid}"} [label=\"${q pid}\\nunknown\", shape=box, style=dashed];";

      assetNode =
        a:
        let
          fill = if a.kind == "switch" then palette.switch else hostFill a.entity;
          shape = if a.kind == "switch" then "box" else "box";
          rolesLine =
            if a.kind == "switch" then
              "role=${a.entity.role}"
            else
              "roles=${concatStringsSep "," a.entity.roles}";
          label = lbl [
            a.id
            "${a.kind} (${a.entity.state})"
            rolesLine
          ];
        in
        "    ${i "a:${a.kind}:${a.id}"} [label=\"${label}\", shape=${shape}, style=\"filled,rounded\", fillcolor=\"${fill}\"];";

      classBlock =
        cls:
        let
          aset = assetsByClass.${cls};
          inside = concatStringsSep "\n" (map assetNode aset);
        in
        ''
          subgraph "cluster_class_${cls}" {
            label="ownership.class=${cls}"; style="rounded,filled"; fillcolor="${palette.rack}";
          ${inside}
          }'';

      ownerEdges =
        a:
        let
          o = a.entity.ownership;
          mk =
            field: style: color:
            if o.${field} or null == null then
              [ ]
            else
              [
                "  ${i "p:${o.${field}}"} -> ${i "a:${a.kind}:${a.id}"} [label=\"${field}\", style=\"${style}\", color=\"${color}\", fontsize=9];"
              ];
        in
        (if o.owner != null then mk "owner" "solid" palette.edgeUplink else [ ])
        ++ (if o.team != null then mk "team" "solid" palette.edgeMlag else [ ])
        ++ mk "operator" "dotted" palette.edgeDownlink
        ++ mk "custodian" "dashed" palette.edgeMgmt;

      principalBlock = concatStringsSep "\n" (map principalNode principalsReferenced);
      classesBlock = concatStringsSep "\n" (map classBlock (sortedAttrNames assetsByClass));
      edgeBlock = concatStringsSep "\n" (concatLists (map ownerEdges assets));
    in
    ''
      digraph "ownership" {
        labelloc="t"; fontsize=18;
        label="Ownership / operator / custodian relationships";
        rankdir=LR; splines=true; concentrate=true; overlap=false;
        node [fontname="Helvetica"]; edge [fontname="Helvetica"];

        subgraph "cluster_principals" {
          label="principals (users + teams)"; style="rounded,filled"; fillcolor="#f8fafc";
      ${principalBlock}
        }

      ${classesBlock}

      ${edgeBlock}
      }
    '';

  hostCardDot =
    h:
    let
      cluster = hostToCluster.${h.id} or "(unclustered)";

      nicRows = map (
        n:
        let
          net = networks.${n.network} or null;
          prefix = if net == null then "-" else firstNonNull [ net.prefix_v4 net.prefix_v6 ] "-";
          ip = if n.ipv4 == null then "" else " ${n.ipv4}";
        in
        "<TR><TD>${xml n.name}</TD><TD>${xml n.role}</TD><TD>${xml n.network}</TD><TD>${xml prefix}${xml ip}</TD><TD>${xml n.mac}</TD></TR>"
      ) h.nics;

      bmcRow =
        if h.bmc == null then
          ""
        else
          "<TR><TD COLSPAN=\"5\"><B>BMC</B></TD></TR>"
          + "<TR><TD>${xml h.bmc.vendor}</TD><TD>${xml h.bmc.ipmi_user}</TD><TD>${xml h.bmc.network}</TD><TD>-</TD><TD>${xml h.bmc.mac}</TD></TR>";

      gpu = if h.hardware.gpu == null then "-" else h.hardware.gpu;
      fpgaCount = toString (length h.hardware.fpgas);
      ram = "${toString h.hardware.ram_gib} GiB";
      cpu = "${h.hardware.cpu_vendor} x${toString h.hardware.cpu_sockets}";

      disko = if h.disko == null then "n/a" else "${h.disko.layout} (${h.disko.root_disk})";

      siteOrHost =
        if h.location.kind == "kvm-guest" then
          "host=${orNull h.location.host "?"}"
        else if h.location.kind == "cloud-vm" then
          "provider=${orNull h.location.provider "?"}"
        else if h.location.site != null then
          "site=${h.location.site}"
        else
          "(no site)";

      rackInfo =
        if h.location.rack == null then
          ""
        else
          " rack=${h.location.rack}"
          + (if h.location.slot == null then "" else " slot=${toString h.location.slot}");

      table = ''
        <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="4">
        <TR><TD COLSPAN="5" BGCOLOR="${palette.host}"><B>${xml h.id}</B></TD></TR>
        <TR><TD>state</TD><TD>${xml h.state}</TD><TD>roles</TD><TD COLSPAN="2">${xml (concatStringsSep ", " h.roles)}</TD></TR>
        <TR><TD>arch</TD><TD>${xml h.hardware.arch}</TD><TD>os</TD><TD COLSPAN="2">${xml h.hardware.os}</TD></TR>
        <TR><TD>cpu</TD><TD>${xml cpu}</TD><TD>ram</TD><TD COLSPAN="2">${xml ram}</TD></TR>
        <TR><TD>gpu</TD><TD>${xml gpu}</TD><TD>fpgas</TD><TD COLSPAN="2">${xml fpgaCount}</TD></TR>
        <TR><TD>cluster</TD><TD>${xml cluster}</TD><TD>location</TD><TD COLSPAN="2">${xml h.location.kind}${xml rackInfo}<BR/>${xml siteOrHost}</TD></TR>
        <TR><TD>owner</TD><TD>${xml (orNull h.ownership.owner "-")}</TD><TD>team</TD><TD COLSPAN="2">${xml (orNull h.ownership.team "-")}</TD></TR>
        <TR><TD>operator</TD><TD>${xml (orNull h.ownership.operator "-")}</TD><TD>custodian</TD><TD COLSPAN="2">${xml (orNull h.ownership.custodian "-")}</TD></TR>
        <TR><TD>class</TD><TD>${xml h.ownership.class}</TD><TD>disko</TD><TD COLSPAN="2">${xml disko}</TD></TR>
        <TR><TD COLSPAN="5" BGCOLOR="${palette.network}"><B>NICs</B></TD></TR>
        <TR><TD><B>name</B></TD><TD><B>role</B></TD><TD><B>network</B></TD><TD><B>prefix / ip</B></TD><TD><B>mac</B></TD></TR>
        ${concatStringsSep "\n" nicRows}
        ${bmcRow}
        </TABLE>>
      '';
    in
    ''
      digraph "host_${h.id}" {
        labelloc="t"; fontsize=14;
        label="Host card: ${h.id}";
        node [fontname="Helvetica"];
        ${i h.id} [shape=plaintext, label=${table}];
      }
    '';

  banner = name: ''
    // AUTO-GENERATED by infra-lib diagrams codegen. Do not edit.
    // Diagram: ${name}
    // Derived from inventory/*.toml -- regenerate with `nix build .#diagrams-*`.
  '';

  renderOne =
    pkgs: name: dotText:
    pkgs.runCommand "${name}.svg"
      {
        nativeBuildInputs = [ pkgs.graphviz ];
        dotSource = banner name + dotText;
        passAsFile = [ "dotSource" ];
      }
      ''
        dot -Tsvg "$dotSourcePath" -o $out
      '';

  collect =
    pkgs: drvName: items:
    pkgs.runCommand drvName { } (
      ''
        mkdir -p $out
      ''
      + concatStringsSep "\n" (
        map (it: ''
          mkdir -p "$out/$(dirname "${it.path}")"
          cp "${it.dot}" "$out/${it.path}.dot"
          cp "${it.svg}" "$out/${it.path}.svg"
        '') items
      )
    );

  mkItem =
    pkgs: relPath: name: dotText:
    let
      dot = pkgs.writeText "${name}.dot" (banner name + dotText);
      svg = renderOne pkgs name dotText;
    in
    {
      path = relPath;
      inherit dot svg;
    };

  layeredFactsJson =
    let
      stripHost = h: {
        inherit (h) id state;
        inherit (h) roles;
        ownership_owner = h.ownership.owner;
        ownership_team = h.ownership.team;
        ownership_class = h.ownership.class;
        arch = h.hardware.arch;
        os = h.hardware.os;
        gpu = h.hardware.gpu;
      };
      stripCluster = c: {
        inherit (c)
          id
          kind
          state
          synthesised
          description
          ;
        scheduler_kind = c.scheduler.kind;
        scheduler_controllers = c.scheduler.controllers;
        partitions = mapAttrs (_: p: {
          inherit (p)
            nodes
            default
            max_time
            gres
            ;
        }) c.scheduler.partitions;
        intra_cluster = c.network.intra_cluster;
      };
      stripUser = u: {
        inherit (u)
          id
          kind
          cohort
          archived
          ;
        username = if u.system_account == null then null else u.system_account.username;
      };
      stripTeam = t: {
        inherit (t) id description;
        members = map (m: { inherit (m) user role; }) t.members;
        synthesised = (t.labels.synthesised or "") == "true";
      };
      intentFacts = {
        inherit (intent) sshGrants slurmSubmitGrants intentViolations;
      };
    in
    builtins.toJSON (
      {
        hosts = mapAttrs (_: stripHost) hosts;
        clusters = mapAttrs (_: stripCluster) clusters;
        teams = mapAttrs (_: stripTeam) teams;
        users = mapAttrs (_: stripUser) users;
        inherit hostsByCluster;
        inherit hostNodeRoles;
        inherit hostToCluster;
        hostsWithSlurmClient = inventory.hostsWithSlurmClient or [ ];
      }
      // intentFacts
    );

in
{
  tailnet =
    { pkgs }:
    let
      pyEnv = pkgs.python3.withPackages (ps: [ ps.svgwrite ]);
      inv = pkgs.writeText "layered-facts.json" layeredFactsJson;
    in
    pkgs.runCommand "diagrams-tailnet" { nativeBuildInputs = [ pyEnv ]; } ''
      mkdir -p $out
      ${pyEnv}/bin/python3 ${./tailnet.py} < ${inv} > $out/tailnet.svg
      cp ${inv} $out/layered-facts.json
    '';

  sshMatrix =
    { pkgs }:
    let
      pyEnv = pkgs.python3.withPackages (ps: [ ps.svgwrite ]);
      inv = pkgs.writeText "layered-facts.json" layeredFactsJson;
    in
    pkgs.runCommand "diagrams-ssh-matrix" { nativeBuildInputs = [ pyEnv ]; } ''
      mkdir -p $out
      ${pyEnv}/bin/python3 ${./ssh-matrix.py} < ${inv} > $out/ssh-matrix.svg
      cp ${inv} $out/layered-facts.json
    '';

  slurmSubmit =
    { pkgs }:
    let
      pyEnv = pkgs.python3.withPackages (ps: [ ps.svgwrite ]);
      inv = pkgs.writeText "layered-facts.json" layeredFactsJson;
    in
    pkgs.runCommand "diagrams-slurm-submit" { nativeBuildInputs = [ pyEnv ]; } ''
      mkdir -p $out
      ${pyEnv}/bin/python3 ${./slurm-submit.py} < ${inv} > $out/slurm-submit.svg
      cp ${inv} $out/layered-facts.json
    '';

  topology =
    { pkgs }:
    let
      items = mapAttrsToList (
        id: topo: mkItem pkgs "topology-${id}" "topology-${id}" (topologyDot topo)
      ) topologies;
    in
    collect pkgs "diagrams-topology" items;

  network =
    { pkgs }:
    let
      items = [ (mkItem pkgs "network-l3" "network-l3" networkDot) ];
    in
    collect pkgs "diagrams-network" items;

  clusterAccess =
    { pkgs }:
    let
      items = [ (mkItem pkgs "cluster-access" "cluster-access" clusterAccessDot) ];
    in
    collect pkgs "diagrams-cluster-access" items;

  ownership =
    { pkgs }:
    let
      items = [ (mkItem pkgs "ownership" "ownership" ownershipDot) ];
    in
    collect pkgs "diagrams-ownership" items;

  host =
    { pkgs }:
    let
      items = mapAttrsToList (hid: h: mkItem pkgs "hosts/${hid}" "host-${hid}" (hostCardDot h)) hosts;
    in
    collect pkgs "diagrams-host" items;
}
