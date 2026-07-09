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

  theme = import ./theme.nix;
  inherit (theme)
    palette
    fleetPalette
    fleetSolo
    fontSize
    ;
  fontFamily = theme.fontFamilyGraphviz;
  fleetSoloColor = fleetSolo;

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
        "  ${i p.switch} -- ${i p.peer} [label=\"${label}\", color=\"${color}\", fontsize=${toString fontSize.edge}];";

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
        labelloc="t"; fontsize=${toString fontSize.title};
        label="Topology: ${topo.id}\n${topo.kind}\n${topo.description}";
        rankdir=TB; splines=true; overlap=false;
        graph [fontname="${fontFamily}"]; node [fontname="${fontFamily}"]; edge [fontname="${fontFamily}"];

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
            "  ${i hid} -- ${i "net:${nic.network}"} [label=\"${q nic.name}\\n${q nic.role}${q ipPart}\", fontsize=${toString fontSize.edge}];";
        in
        map mkEdge attached;

      bmcEdges =
        hid: h:
        if h.bmc == null then
          [ ]
        else
          [
            "  ${i hid} -- ${i "net:${h.bmc.network}"} [label=\"bmc/${q h.bmc.vendor}\", style=dashed, fontsize=${toString fontSize.edge}, color=\"${palette.edgeMgmt}\"];"
          ];

      switchMgmtEdges =
        sid: s:
        if s.mgmt_network == null then
          [ ]
        else
          [
            "  ${i "sw:${sid}"} -- ${i "net:${s.mgmt_network}"} [label=\"mgmt\", style=dashed, fontsize=${toString fontSize.edge}, color=\"${palette.edgeMgmt}\"];"
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
        labelloc="t"; fontsize=${toString fontSize.title}; label="Networks / L3 attachments";
        rankdir=LR; splines=true; overlap=false;
        graph [fontname="${fontFamily}"]; node [fontname="${fontFamily}"]; edge [fontname="${fontFamily}"];

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

  paletteAt = idx: elemAt fleetPalette (mod idx (length fleetPalette));

  multiHostClusters = filter (cid: length (hostsByCluster.${cid} or [ ]) > 1) clustersBySize;

  fleetColors = listToAttrs (imap0 (i: cid: nameValuePair cid (paletteAt i)) multiHostClusters);

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
        + " fontsize=${toString fontSize.label}];";

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
        + " fontsize=${toString fontSize.body}];";

      teamMemberEdges =
        tid:
        let
          t = teams.${tid} or null;
        in
        if t == null then
          [ ]
        else
          map (
            m:
            "  ${i "user:${m.user}"} -> ${i "team:${tid}"} [label=\"${q m.role}\", fontsize=${toString fontSize.edge}];"
          ) t.members;

      teamClusterEdges =
        cid:
        let
          c = activeClusters.${cid};
        in
        map (
          g:
          "  ${i "team:${g.team}"} -> ${i "cluster:${cid}"} [label=\"${q (tierLabel g.tier)}\", color=\"${palette.edgeUplink}\", fontsize=${toString fontSize.edge}];"
        ) c.access.teams;

      userClusterEdges =
        cid:
        let
          c = activeClusters.${cid};
        in
        map (
          g:
          "  ${i "user:${g.user}"} -> ${i "cluster:${cid}"} [label=\"${q g.tier}\", color=\"${palette.edgeMlag}\", style=dashed, fontsize=${toString fontSize.edge}];"
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
        labelloc="t"; fontsize=${toString fontSize.title};
        label="Cluster access: users -> teams -> clusters -> hosts";
        rankdir=LR; splines=true; concentrate=true; overlap=false;
        graph [fontname="${fontFamily}"]; node [fontname="${fontFamily}"]; edge [fontname="${fontFamily}"];

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
      hostAssets = mapAttrsToList (id: h: {
        kind = "host";
        inherit id;
        entity = h;
      }) hosts;
      switchAssets = mapAttrsToList (id: s: {
        kind = "switch";
        inherit id;
        entity = s;
      }) switches;
      allAssets = hostAssets ++ switchAssets;

      ownersOf =
        a:
        let
          o = a.entity.ownership or { };
        in
        {
          owner = o.owner or null;
          team = o.team or null;
          operator = o.operator or null;
          custodian = o.custodian or null;
          class = o.class or "-";
        };

      kindOrder =
        k:
        {
          host = 0;
          switch = 1;
        }
        .${k} or 9;
      sortedAssets = sort (
        a: b:
        let
          ca = (ownersOf a).class;
          cb = (ownersOf b).class;
        in
        if ca != cb then
          ca < cb
        else if a.kind != b.kind then
          kindOrder a.kind < kindOrder b.kind
        else
          a.id < b.id
      ) allAssets;

      principalsReferenced =
        let
          fromAsset =
            a:
            let
              o = ownersOf a;
            in
            filter (x: x != null) [
              o.owner
              o.team
              o.operator
              o.custodian
            ];
        in
        unique (concatLists (map fromAsset allAssets));

      userPrincipals = sort lessThan (filter (p: users ? ${p}) principalsReferenced);
      teamPrincipals = sort lessThan (filter (p: teams ? ${p}) principalsReferenced);
      unknownPrincipals = sort lessThan (
        filter (p: !(users ? ${p}) && !(teams ? ${p})) principalsReferenced
      );
      orderedPrincipals = userPrincipals ++ teamPrincipals ++ unknownPrincipals;
      nCols = length sortedAssets;
      totalCols = 1 + nCols;

      assetHeaderCell =
        a:
        let
          o = ownersOf a;
          bg =
            if a.kind == "host" then
              (fleetColorFor (hostToCluster.${a.id} or "-")).fill
            else if a.kind == "switch" then
              palette.switch
            else
              palette.panelBg;
        in
        "<TD BGCOLOR=\"${bg}\"><B>${xml a.id}</B><BR/><FONT POINT-SIZE=\"${toString fontSize.small}\" COLOR=\"${palette.textMuted}\">${xml a.kind} &#183; ${xml o.class}</FONT></TD>";

      ownSlot =
        present: color: sym:
        if present then
          "<FONT COLOR=\"${color}\"><B>${sym}</B></FONT>&#160;"
        else
          "<FONT COLOR=\"${palette.textFaint}\">.</FONT>&#160;";

      ownCell =
        pid: a:
        let
          o = ownersOf a;
          isTeamPrincipal = teams ? ${pid};
          isOwner = if isTeamPrincipal then o.team == pid else o.owner == pid;
          isOperator = o.operator == pid;
          isCustodian = o.custodian == pid;
          line =
            "<FONT FACE=\"DejaVu Sans Mono\">"
            + (ownSlot isOwner palette.edgeUplink "O")
            + (ownSlot isOperator palette.edgeDownlink "P")
            + (ownSlot isCustodian palette.edgeMgmt "C")
            + "</FONT>";
        in
        "<TD ALIGN=\"CENTER\">${line}</TD>";

      principalRow =
        pid:
        let
          nameCell =
            if users ? ${pid} then
              let
                u = users.${pid};
                uname =
                  if u.system_account != null && u.system_account.username != null then
                    u.system_account.username
                  else
                    "-";
                cohort = u.cohort or "";
                sub = if cohort == "" then "user" else "user &#183; ${xml cohort}";
              in
              "<B>${xml uname}</B><BR/><FONT POINT-SIZE=\"${toString fontSize.small}\" COLOR=\"${palette.textFaint}\">${sub}</FONT>"
            else if teams ? ${pid} then
              let
                t = teams.${pid};
                desc = t.description or "";
                n = length (t.members or [ ]);
                sub = "team &#183; ${toString n} members";
              in
              "<B>${
                xml (if desc == "" then "-" else desc)
              }</B><BR/><FONT POINT-SIZE=\"${toString fontSize.small}\" COLOR=\"${palette.textFaint}\">${sub}</FONT>"
            else
              "<B>-</B><BR/><FONT POINT-SIZE=\"${toString fontSize.small}\" COLOR=\"${palette.textFaint}\">unknown</FONT>";
        in
        "<TR>"
        + "<TD ALIGN=\"LEFT\"><B>${xml pid}</B></TD>"
        + "<TD ALIGN=\"LEFT\">${nameCell}</TD>"
        + concatStringsSep "" (map (ownCell pid) sortedAssets)
        + "</TR>";

      headerRow =
        "<TR>"
        + "<TD BGCOLOR=\"${palette.panelBg}\"><B>Principal ID</B></TD>"
        + "<TD BGCOLOR=\"${palette.panelBg}\"><B>Name</B></TD>"
        + concatStringsSep "" (map assetHeaderCell sortedAssets)
        + "</TR>";

      mainTable = ''
        <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
        <TR><TD COLSPAN="${toString (totalCols + 1)}" BGCOLOR="${palette.host}"><B>Ownership matrix</B></TD></TR>
        ${headerRow}
        ${concatStringsSep "\n" (map principalRow orderedPrincipals)}
        </TABLE>>
      '';

      legendTable =
        let
          ownMarkerRow =
            colorHex: label: sym:
            "<TR><TD ALIGN=\"CENTER\"><FONT FACE=\"DejaVu Sans Mono\" COLOR=\"${colorHex}\"><B>${sym}</B></FONT></TD><TD ALIGN=\"LEFT\">${label}</TD></TR>";
          classes = unique (map (a: (ownersOf a).class) sortedAssets);
          sortedClasses = sort lessThan classes;
          classCountsRow =
            cls:
            let
              n = length (filter (a: (ownersOf a).class == cls) sortedAssets);
            in
            "<TR><TD ALIGN=\"LEFT\"><B>${xml cls}</B></TD><TD ALIGN=\"CENTER\">${toString n}</TD></TR>";
        in
        ''
          <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
          <TR><TD COLSPAN="2" BGCOLOR="${palette.panelBg}"><B>Legend</B></TD></TR>
          <TR><TD COLSPAN="2" BGCOLOR="${palette.network}"><B>Markers</B></TD></TR>
          ${ownMarkerRow palette.edgeUplink "owner (user or team)" "O"}
          ${ownMarkerRow palette.edgeDownlink "operator" "P"}
          ${ownMarkerRow palette.edgeMgmt "custodian" "C"}
          <TR><TD ALIGN="CENTER"><FONT FACE="DejaVu Sans Mono" COLOR="${palette.textFaint}">.</FONT></TD><TD ALIGN="LEFT">absent slot</TD></TR>
          <TR><TD COLSPAN="2" BGCOLOR="${palette.network}"><B>ownership.class counts</B></TD></TR>
          ${concatStringsSep "\n" (map classCountsRow sortedClasses)}
          </TABLE>>
        '';
    in
    ''
      digraph "ownership" {
        graph [fontname="${fontFamily}", rankdir=TB, nodesep=0.4, ranksep=0.4];
        node [fontname="${fontFamily}", shape=plaintext];
        edge [fontname="${fontFamily}"];
        matrix [label=${mainTable}];
        legend [label=${legendTable}];
        matrix -> legend [style=invis];
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
      ram = "${toString h.hardware.ram_gib} GB";
      cpu =
        let
          s = h.hardware.cpu_sockets;
          c = h.hardware.cpu_cores_per_socket;
          t = h.hardware.cpu_threads_per_core;
          physical = s * c;
          derived = physical * t;
          logical = if h.hardware.cpu_logical_count == null then derived else h.hardware.cpu_logical_count;
          hybridMark = if h.hardware.cpu_logical_count == null then "" else " hybrid";
        in
        "${h.hardware.cpu_vendor} (${toString s}s / ${toString physical}c / ${toString logical}t${hybridMark})";

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

      kvRow =
        k1: v1: k2: v2:
        "<TR><TD><B>${k1}</B></TD><TD>${v1}</TD><TD><B>${k2}</B></TD><TD COLSPAN=\"2\">${v2}</TD></TR>";
      infoRows = concatStringsSep "\n" [
        (kvRow "State" (xml h.state) "Roles" (xml (concatStringsSep ", " h.roles)))
        (kvRow "Arch" (xml h.hardware.arch) "OS" (xml h.hardware.os))
        (kvRow "CPU" (xml cpu) "RAM" (xml ram))
        (kvRow "GPU" (xml gpu) "FPGAs" (xml fpgaCount))
        (kvRow "Cluster" (xml cluster) "Location" (
          xml h.location.kind + xml rackInfo + "<BR/>" + xml siteOrHost
        ))
        (kvRow "Owner" (xml (orNull h.ownership.owner "-")) "Team" (xml (orNull h.ownership.team "-")))
        (kvRow "Operator" (xml (orNull h.ownership.operator "-")) "Custodian" (
          xml (orNull h.ownership.custodian "-")
        ))
        (kvRow "Class" (xml h.ownership.class) "Disko" (xml disko))
      ];
      table = ''
        <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="4">
        <TR><TD COLSPAN="5" BGCOLOR="${palette.host}"><B>${xml h.id}</B></TD></TR>
        ${infoRows}
        <TR><TD COLSPAN="5" BGCOLOR="${palette.network}"><B>NICs</B></TD></TR>
        <TR><TD><B>Name</B></TD><TD><B>Role</B></TD><TD><B>Network</B></TD><TD><B>Prefix / IP</B></TD><TD><B>MAC</B></TD></TR>
        ${concatStringsSep "\n" nicRows}
        ${bmcRow}
        </TABLE>>
      '';
    in
    ''
      digraph "host_${h.id}" {
        graph [fontname="${fontFamily}"]; node [fontname="${fontFamily}"]; edge [fontname="${fontFamily}"];
        ${i h.id} [shape=plaintext, label=${table}];
      }
    '';

  sshMatrixDot =
    let
      activeClusterIds = attrNames (filterAttrs (_: c: c.state != "retired") clusters);
      hostCountOf = cid: length (hostsByCluster.${cid} or [ ]);
      multiCids = sort (
        a: b: if hostCountOf a != hostCountOf b then hostCountOf a > hostCountOf b else a < b
      ) (filter (cid: hostCountOf cid > 1) activeClusterIds);
      soloCids = sort lessThan (filter (cid: hostCountOf cid <= 1) activeClusterIds);
      orderedCids = multiCids ++ soloCids;

      cols = concatMap (
        cid: map (hid: { inherit hid cid; }) (sort lessThan (hostsByCluster.${cid} or [ ]))
      ) orderedCids;
      nCols = length cols;
      totalCols = 1 + nCols;

      activeUsers = filterAttrs (
        _: u: u.system_account != null && u.system_account.username != null && !u.archived
      ) users;
      userIds = sort lessThan (attrNames activeUsers);

      liveGrants = filter (g: !(g.archived or false) && g.account != null) intent.sshGrants;
      grantsAt = uid: hid: filter (g: g.user == uid && g.host == hid) liveGrants;

      violations = intent.intentViolations or [ ];
      hasViolation = uid: hid: any (v: (v.user or null) == uid && (v.host or null) == hid) violations;

      slot =
        present: color: sym:
        if present then
          "<FONT COLOR=\"${color}\"><B>${sym}</B></FONT>&#160;"
        else
          "<FONT COLOR=\"${palette.textFaint}\">.</FONT>&#160;";

      marker =
        uid: col:
        let
          gs = grantsAt uid col.hid;
          accts = map (g: g.account) gs;
          srcs = map (g: g.source or "") gs;
          tiers = filter (t: t != "" && t != null) (unique (map (g: g.tier or "") gs));
          hasRoot = elem "root" accts || elem "cohort:admin" srcs;
          hasTrust = elem "ssh_trust" srcs;
          hasReg = any (a: a != "root") accts;
          hasViol = hasViolation uid col.hid;

          markerLine =
            "<FONT FACE=\"DejaVu Sans Mono\">"
            + (slot hasRoot palette.danger "R")
            + (slot hasReg palette.text "A")
            + (slot hasTrust palette.partitionBorder "T")
            + (slot hasViol palette.danger "!")
            + "</FONT>";

          tierLine =
            if tiers == [ ] then
              ""
            else
              "<BR/><FONT POINT-SIZE=\"${toString fontSize.small}\" COLOR=\"${palette.textMuted}\">${xml (concatStringsSep ", " tiers)}</FONT>";
        in
        "<TD ALIGN=\"CENTER\">${markerLine}${tierLine}</TD>";

      hostHeaderRow =
        "<TR>"
        + "<TD BGCOLOR=\"${palette.panelBg}\"><B>User ID</B></TD>"
        + "<TD BGCOLOR=\"${palette.panelBg}\"><B>Username</B></TD>"
        + concatStringsSep "" (
          map (
            col:
            let
              c = fleetColorFor col.cid;
            in
            "<TD BGCOLOR=\"${c.fill}\"><B>${xml col.hid}</B><BR/><FONT POINT-SIZE=\"${toString fontSize.small}\" COLOR=\"${palette.textMuted}\">${xml col.cid}</FONT></TD>"
          ) cols
        )
        + "</TR>";

      userRow =
        uid:
        let
          u = users.${uid};
          uname =
            if u.system_account != null && u.system_account.username != null then
              u.system_account.username
            else
              "-";
          cohort = u.cohort or "";
        in
        "<TR>"
        + "<TD ALIGN=\"LEFT\"><B>${xml uid}</B></TD>"
        + "<TD ALIGN=\"LEFT\"><B>${xml uname}</B>${
          if cohort == "" then
            ""
          else
            "<BR/><FONT POINT-SIZE=\"${toString fontSize.small}\" COLOR=\"${palette.textFaint}\">${xml cohort}</FONT>"
        }</TD>"
        + concatStringsSep "" (map (marker uid) cols)
        + "</TR>";

      mainTable = ''
        <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
        <TR><TD COLSPAN="${toString (totalCols + 1)}" BGCOLOR="${palette.host}"><B>SSH access matrix</B></TD></TR>
        ${hostHeaderRow}
        ${concatStringsSep "\n" (map userRow userIds)}
        </TABLE>>
      '';

      legendTable =
        let
          markerRow =
            colorHex: label: sym:
            "<TR><TD ALIGN=\"CENTER\"><FONT FACE=\"DejaVu Sans Mono\" COLOR=\"${colorHex}\"><B>${sym}</B></FONT></TD><TD ALIGN=\"LEFT\">${label}</TD></TR>";
          clusterRow =
            cid:
            let
              c = fleetColorFor cid;
              members = concatStringsSep ", " (hostsByCluster.${cid} or [ ]);
            in
            "<TR><TD BGCOLOR=\"${c.fill}\"><B>${xml cid}</B></TD><TD ALIGN=\"LEFT\">${xml members}</TD></TR>";
        in
        ''
          <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
          <TR><TD COLSPAN="2" BGCOLOR="${palette.panelBg}"><B>Legend</B></TD></TR>
          <TR><TD COLSPAN="2" BGCOLOR="${palette.network}"><B>Markers</B></TD></TR>
          ${markerRow palette.danger "root account (uid=0)" "R"}
          ${markerRow palette.text "user account grant" "A"}
          ${markerRow palette.partitionBorder "ssh_trust overlay" "T"}
          <TR><TD ALIGN="CENTER"><FONT FACE="DejaVu Sans Mono" COLOR="${palette.textFaint}">.</FONT></TD><TD ALIGN="LEFT">absent slot</TD></TR>
          ${markerRow palette.danger "headscale intent violation" "!"}
          <TR><TD COLSPAN="2" BGCOLOR="${palette.network}"><B>Clusters</B></TD></TR>
          ${concatStringsSep "\n" (map clusterRow orderedCids)}
          </TABLE>>
        '';
    in
    ''
      digraph "ssh_matrix" {
        graph [fontname="${fontFamily}", rankdir=TB, nodesep=0.4, ranksep=0.4];
        node [fontname="${fontFamily}", shape=plaintext];
        edge [fontname="${fontFamily}"];
        matrix [label=${mainTable}];
        legend [label=${legendTable}];
        matrix -> legend [style=invis];
      }
    '';

  tailnetDot =
    let
      activeClusterIds = attrNames (filterAttrs (_: c: c.state != "retired") clusters);
      hostCountOf = cid: length (hostsByCluster.${cid} or [ ]);
      multiCids = sort (
        a: b: if hostCountOf a != hostCountOf b then hostCountOf a > hostCountOf b else a < b
      ) (filter (cid: hostCountOf cid > 1) activeClusterIds);
      soloCids = sort lessThan (filter (cid: hostCountOf cid <= 1) activeClusterIds);
      orderedCids = multiCids ++ soloCids;

      hostTags =
        h:
        let
          cid = hostToCluster.${h.id} or null;
          cluster = if cid == null then null else clusters.${cid} or null;
          clusterTag =
            if cluster == null then
              null
            else if (cluster.network.tailscale_tag or null) != null then
              cluster.network.tailscale_tag
            else
              "tag:${cid}";
          stripTag = t: removePrefix "tag:" t;
          base = if clusterTag == null then null else stripTag clusterTag;

          isIn = bucket: elem h.id (bucket.${cid} or [ ]);
          categories =
            optional (isIn (inventory.loginNodesOfCluster or { })) "login"
            ++ optional (isIn (inventory.computeNodesOfCluster or { })) "compute"
            ++ optional (isIn (inventory.storageNodesOfCluster or { })) "storage"
            ++ optional (isIn (inventory.controllerNodesOfCluster or { })) "controller";
          roleTags = if base == null then [ ] else map (r: "tag:${base}-${r}") categories;
        in
        (if clusterTag == null then [ ] else [ clusterTag ]) ++ roleTags;

      hostRow =
        h:
        let
          cid = hostToCluster.${h.id} or "-";
          c = if cid == "-" then fleetSoloColor else fleetColorFor cid;
          tags = hostTags h;
          tagStr = if tags == [ ] then "-" else concatStringsSep "<BR/>" (map xml tags);
          roles = if h.roles == [ ] then "-" else concatStringsSep ", " h.roles;
          nrs = hostNodeRoles.${h.id} or [ ];
          nrsStr = if nrs == [ ] then "-" else concatStringsSep ", " nrs;
        in
        "<TR>"
        + "<TD ALIGN=\"LEFT\"><B>${xml h.id}</B></TD>"
        + "<TD BGCOLOR=\"${c.fill}\" ALIGN=\"LEFT\">${xml cid}</TD>"
        + "<TD ALIGN=\"LEFT\">${xml h.state}</TD>"
        + "<TD ALIGN=\"LEFT\">${xml h.hardware.arch}</TD>"
        + "<TD ALIGN=\"LEFT\">${xml roles}</TD>"
        + "<TD ALIGN=\"LEFT\">${xml nrsStr}</TD>"
        + "<TD ALIGN=\"LEFT\">${tagStr}</TD>"
        + "</TR>";

      rowsByCluster = concatMap (
        cid:
        let
          hs = sort lessThan (hostsByCluster.${cid} or [ ]);
        in
        map (hid: hosts.${hid}) hs
      ) orderedCids;

      unclustered = filter (h: !(hasAttr h.id hostToCluster)) (attrValues hosts);
      allRows = rowsByCluster ++ (sort (a: b: a.id < b.id) unclustered);

      table = ''
        <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
        <TR><TD COLSPAN="7" BGCOLOR="${palette.host}"><B>Tailnet fleet</B></TD></TR>
        <TR>
          <TD BGCOLOR="${palette.panelBg}"><B>Host</B></TD>
          <TD BGCOLOR="${palette.panelBg}"><B>Cluster</B></TD>
          <TD BGCOLOR="${palette.panelBg}"><B>State</B></TD>
          <TD BGCOLOR="${palette.panelBg}"><B>Arch</B></TD>
          <TD BGCOLOR="${palette.panelBg}"><B>Roles</B></TD>
          <TD BGCOLOR="${palette.panelBg}"><B>Node roles</B></TD>
          <TD BGCOLOR="${palette.panelBg}"><B>Tailscale tag</B></TD>
        </TR>
        ${concatStringsSep "\n" (map hostRow allRows)}
        </TABLE>>
      '';

    in
    ''
      digraph "tailnet" {
        graph [fontname="${fontFamily}", rankdir=TB, nodesep=0.4, ranksep=0.4];
        node [fontname="${fontFamily}", shape=plaintext];
        edge [fontname="${fontFamily}"];
        fleet [label=${table}];
      }
    '';

  slurmSubmitDot =
    let
      grants = intent.slurmSubmitGrants or [ ];
      sortedGrants = sort (
        a: b:
        if a.user != b.user then
          a.user < b.user
        else if a.fromHost != b.fromHost then
          a.fromHost < b.fromHost
        else
          (a.toCluster or "") < (b.toCluster or "")
      ) grants;

      grantRow =
        g:
        let
          cid = g.toCluster or "-";
          c = if cid == "-" then fleetSoloColor else fleetColorFor cid;
        in
        "<TR>"
        + "<TD ALIGN=\"LEFT\"><B>${xml g.user}</B></TD>"
        + "<TD ALIGN=\"LEFT\">${xml g.fromHost}</TD>"
        + "<TD BGCOLOR=\"${c.fill}\" ALIGN=\"LEFT\">${xml cid}</TD>"
        + "</TR>";

      grantsTable =
        if sortedGrants == [ ] then
          ''
            <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
            <TR><TD BGCOLOR="${palette.host}"><B>Slurm submit grants</B></TD></TR>
            <TR><TD ALIGN="LEFT"><I>none</I></TD></TR>
            </TABLE>>
          ''
        else
          ''
            <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
            <TR><TD COLSPAN="3" BGCOLOR="${palette.host}"><B>Slurm submit grants</B></TD></TR>
            <TR>
              <TD BGCOLOR="${palette.panelBg}"><B>User</B></TD>
              <TD BGCOLOR="${palette.panelBg}"><B>From host</B></TD>
              <TD BGCOLOR="${palette.panelBg}"><B>To cluster</B></TD>
            </TR>
            ${concatStringsSep "\n" (map grantRow sortedGrants)}
            </TABLE>>
          '';
    in
    ''
      digraph "slurm_submit" {
        graph [fontname="${fontFamily}", rankdir=TB, nodesep=0.4, ranksep=0.4];
        node [fontname="${fontFamily}", shape=plaintext];
        edge [fontname="${fontFamily}"];
        grants [label=${grantsTable}];
      }
    '';

  clusterRolesDot =
    let
      activeClusters = filterAttrs (_: c: c.state != "retired") clusters;
      orderedCids = sort lessThan (attrNames activeClusters);

      clientHosts = inventory.hostsWithSlurmClient or [ ];

      partitionNodesFor = c: unique (concatLists (mapAttrsToList (_: p: p.nodes) c.scheduler.partitions));

      hostSlot =
        present: color: sym:
        if present then
          "<FONT COLOR=\"${color}\"><B>${sym}</B></FONT>&#160;"
        else
          "<FONT COLOR=\"${palette.textFaint}\">.</FONT>&#160;";

      hostRow =
        cid: hid:
        let
          c = activeClusters.${cid};
          isController = elem hid c.scheduler.controllers;
          isCompute = elem hid (partitionNodesFor c);
          isSubmit = elem hid clientHosts;
          cc = fleetColorFor cid;
          rolesLine =
            "<FONT FACE=\"DejaVu Sans Mono\">"
            + (hostSlot isController palette.controllerBorder "C")
            + (hostSlot isCompute palette.computeBorder "N")
            + (hostSlot isSubmit palette.submitBorder "S")
            + "</FONT>";
        in
        "<TR>"
        + "<TD BGCOLOR=\"${cc.fill}\" ALIGN=\"LEFT\"><B>${xml cid}</B></TD>"
        + "<TD ALIGN=\"LEFT\"><B>${xml hid}</B></TD>"
        + "<TD ALIGN=\"CENTER\">${rolesLine}</TD>"
        + "</TR>";

      clusterRows =
        cid:
        let
          c = activeClusters.${cid};
          members = hostsByCluster.${cid} or [ ];
          participants = unique (members ++ c.scheduler.controllers);
          hosts' = sort lessThan participants;
        in
        map (hid: hostRow cid hid) hosts';

      allRows = concatLists (map clusterRows orderedCids);

      table = ''
        <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
        <TR><TD COLSPAN="3" BGCOLOR="${palette.host}"><B>Cluster roles</B></TD></TR>
        <TR>
          <TD BGCOLOR="${palette.panelBg}"><B>Cluster</B></TD>
          <TD BGCOLOR="${palette.panelBg}"><B>Host</B></TD>
          <TD BGCOLOR="${palette.panelBg}"><B>C N S</B></TD>
        </TR>
        ${concatStringsSep "\n" allRows}
        </TABLE>>
      '';

      legendTable =
        let
          markerRow =
            colorHex: label: sym:
            "<TR><TD ALIGN=\"CENTER\"><FONT FACE=\"DejaVu Sans Mono\" COLOR=\"${colorHex}\"><B>${sym}</B></FONT></TD><TD ALIGN=\"LEFT\">${label}</TD></TR>";
        in
        ''
          <<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6">
          <TR><TD COLSPAN="2" BGCOLOR="${palette.panelBg}"><B>Legend</B></TD></TR>
          ${markerRow palette.controllerBorder "controller (runs slurmctld)" "C"}
          ${markerRow palette.computeBorder "compute node (runs slurmd; in a partition)" "N"}
          ${markerRow palette.submitBorder "submit client (can sbatch)" "S"}
          <TR><TD ALIGN="CENTER"><FONT FACE="DejaVu Sans Mono" COLOR="${palette.textFaint}">.</FONT></TD><TD ALIGN="LEFT">absent slot</TD></TR>
          </TABLE>>
        '';
    in
    ''
      digraph "cluster_roles" {
        graph [fontname="${fontFamily}", rankdir=TB, nodesep=0.4, ranksep=0.4];
        node [fontname="${fontFamily}", shape=plaintext];
        edge [fontname="${fontFamily}"];
        roles [label=${table}];
        legend [label=${legendTable}];
        roles -> legend [style=invis];
      }
    '';

  banner = name: ''
    // AUTO-GENERATED by infra-lib diagrams codegen. Do not edit.
    // Diagram: ${name}
    // Derived from inventory/*.nix -- regenerate with `nix build .#diagrams-*`.
  '';

  renderOne =
    pkgs: name: dotText:
    pkgs.runCommand "${name}.svg"
      {
        nativeBuildInputs = [ pkgs.graphviz ];
        dotSource = banner name + dotText;
        passAsFile = [ "dotSource" ];
        FONTCONFIG_FILE = pkgs.makeFontsConf {
          fontDirectories = [ pkgs.dejavu_fonts ];
        };
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

in
{
  tailnet =
    { pkgs }:
    let
      items = [ (mkItem pkgs "tailnet" "tailnet" tailnetDot) ];
    in
    collect pkgs "diagrams-tailnet" items;

  sshMatrix =
    { pkgs }:
    let
      items = [ (mkItem pkgs "ssh-matrix" "ssh-matrix" sshMatrixDot) ];
    in
    collect pkgs "diagrams-ssh-matrix" items;

  slurmSubmit =
    { pkgs }:
    let
      items = [ (mkItem pkgs "slurm-submit" "slurm-submit" slurmSubmitDot) ];
    in
    collect pkgs "diagrams-slurm-submit" items;

  clusterRoles =
    { pkgs }:
    let
      items = [ (mkItem pkgs "cluster-roles" "cluster-roles" clusterRolesDot) ];
    in
    collect pkgs "diagrams-cluster-roles" items;

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
      normalizer =
        pkgs.writers.writePython3 "normalize-host-cards"
          {
            flakeIgnore = [
              "E501"
              "E203"
            ];
          }
          ''
            import glob
            import re
            import sys

            open_re = re.compile(
                r'(<svg[^>]*width=")([\d.]+)(pt"[^>]*height=")([\d.]+)(pt"[^>]*viewBox=")([^"]+)(")',
                re.DOTALL,
            )

            paths = sorted(glob.glob(sys.argv[1] + "/hosts/*.svg"))
            parsed = []
            for path in paths:
                with open(path) as fh:
                    content = fh.read()
                m = open_re.search(content)
                if not m:
                    continue
                width = float(m.group(2))
                height = float(m.group(4))
                parsed.append((path, content, m, width, height))

            if not parsed:
                sys.exit(0)

            max_w = max(width for (_, _, _, width, _) in parsed)
            max_h = max(height for (_, _, _, _, height) in parsed)

            for path, content, m, _, _ in parsed:
                replacement = (
                    f"{m.group(1)}{max_w:g}{m.group(3)}{max_h:g}"
                    f'{m.group(5)}0 0 {max_w:g} {max_h:g}{m.group(7)}'
                )
                new_content = content[: m.start()] + replacement + content[m.end():]
                with open(path, "w") as fh:
                    fh.write(new_content)
          '';
      items = mapAttrsToList (hid: h: mkItem pkgs "hosts/${hid}" "host-${hid}" (hostCardDot h)) hosts;
      raw = collect pkgs "diagrams-host-raw" items;
    in
    pkgs.runCommand "diagrams-host" { } ''
      mkdir -p $out
      cp -r ${raw}/. $out/
      chmod -R u+w $out
      ${normalizer} $out
    '';
}
