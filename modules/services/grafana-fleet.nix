{
  cluster,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  datasource = {
    type = "prometheus";
    uid = "\${datasource}";
  };
  metricsDirectory = "/var/lib/prometheus-node-exporter-textfiles";
  provisionedHosts = lib.sort (a: b: a.id < b.id) (
    lib.filter (host: host.state == "provisioned") (lib.attrValues (cluster.hosts or { }))
  );
  boolString = value: if value then "true" else "false";
  prometheusLabel = value: lib.replaceStrings [ "\\" "\"" "\n" ] [ "\\\\" "\\\"" "\\n" ] value;
  monitoringPolicyLines = map (
    host:
    let
      enabled = host.monitoring.enabled or true;
      alwaysOn = host.monitoring.always_on or true;
      exporters = host.monitoring.exporters or [ ];
      mode =
        if !enabled then
          "disabled"
        else if alwaysOn then
          "always_on"
        else
          "optional";
      hasExporter = exporter: enabled && lib.elem exporter exporters;
    in
    ''fleet_monitoring_policy_info{host="${prometheusLabel host.id}",mode="${mode}",node="${boolString (hasExporter "node")}",smartctl="${boolString (hasExporter "smartctl")}"} 1''
  ) provisionedHosts;
  monitoringPolicyMetrics = pkgs.writeText "fleet-monitoring-policy.prom" ''
    # HELP fleet_monitoring_policy_info Inventory monitoring policy for provisioned fleet hosts.
    # TYPE fleet_monitoring_policy_info gauge
    ${lib.concatStringsSep "\n" monitoringPolicyLines}
  '';
  expectedTagLines = lib.concatMap (
    host:
    map (
      tag: ''fleet_expected_tag_info{host="${prometheusLabel host.id}",tag="${prometheusLabel tag}"} 1''
    ) (inputs.self.lib.intent.hostPolicyTags.${host.id} or [ ])
  ) provisionedHosts;
  expectedTagMetrics = pkgs.writeText "fleet-expected-tags.prom" ''
    # HELP fleet_expected_tag_info Expected headscale ACL policy tag per provisioned host.
    # TYPE fleet_expected_tag_info gauge
    ${lib.concatStringsSep "\n" expectedTagLines}
  '';
  tailnetMetricsCollector = pkgs.writeShellApplication {
    name = "collect-fleet-tailnet-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.headscale
      pkgs.jq
    ];
    text = ''
      mkdir -p ${metricsDirectory}
      output="$(mktemp ${metricsDirectory}/fleet-tailnet.prom.XXXXXX)"
      trap 'rm -f "$output"' EXIT

      nodes="$(headscale nodes list --output json)"

      {
        printf '%s\n' '# HELP fleet_tailnet_node_status Headscale node state: 1=offline, 2=online.'
        printf '%s\n' '# TYPE fleet_tailnet_node_status gauge'
        printf '%s' "$nodes" | jq -r '
          def prom_escape:
            gsub("\\\\"; "\\\\\\\\")
            | gsub("\""; "\\\"")
            | gsub("\n"; "\\n");
          .[]
          | (.given_name // .name) as $host
          | ([.ip_addresses[]? | select(test("^[0-9]+[.]"))][0] // "") as $ipv4
          | ([.tags[]?] | sort | join(",")) as $tags
          | "fleet_tailnet_node_status{host=\"\($host | prom_escape)\",ipv4=\"\($ipv4 | prom_escape)\",tags=\"\($tags | prom_escape)\"} \(if .online then 2 else 1 end)"
        '
        printf '%s\n' '# HELP fleet_tailnet_node_tag_info Headscale ACL policy tag currently on a tailnet node.'
        printf '%s\n' '# TYPE fleet_tailnet_node_tag_info gauge'
        printf '%s' "$nodes" | jq -r '
          def prom_escape:
            gsub("\\\\"; "\\\\\\\\")
            | gsub("\""; "\\\"")
            | gsub("\n"; "\\n");
          .[]
          | (.given_name // .name) as $host
          | .tags[]?
          | "fleet_tailnet_node_tag_info{host=\"\($host | prom_escape)\",tag=\"\(. | prom_escape)\"} 1"
        '
      } > "$output"

      chmod 0644 "$output"
      mv "$output" ${metricsDirectory}/fleet-tailnet.prom
      trap - EXIT
    '';
  };
  mainRevisionCollector = pkgs.writeShellApplication {
    name = "collect-dotfiles-main-revision";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      mkdir -p ${metricsDirectory}
      output="$(mktemp ${metricsDirectory}/fleet-main-revision.prom.XXXXXX)"
      trap 'rm -f "$output"' EXIT

      revision="$(
        curl -fsSL --connect-timeout 10 --max-time 30 \
          -H 'Accept: application/vnd.github+json' \
          -H 'User-Agent: fleet-revision-collector' \
          https://api.github.com/repos/hakan-demirli/dotfiles/commits/main \
          | jq -er '.sha | select(test("^[0-9a-f]{40}$"))'
      )"
      shortRevision="''${revision:0:12}"

      {
        printf '%s\n' '# HELP fleet_configuration_main_info Current commit on the dotfiles main branch.'
        printf '%s\n' '# TYPE fleet_configuration_main_info gauge'
        printf 'fleet_configuration_main_info{revision="%s",short_revision="%s"} 1\n' \
          "$revision" "$shortRevision"
        printf '%s\n' '# HELP fleet_configuration_main_fetch_timestamp_seconds Last successful main-branch revision check.'
        printf '%s\n' '# TYPE fleet_configuration_main_fetch_timestamp_seconds gauge'
        printf 'fleet_configuration_main_fetch_timestamp_seconds %s\n' "$(date +%s)"
      } > "$output"

      chmod 0644 "$output"
      mv "$output" ${metricsDirectory}/fleet-main-revision.prom
      trap - EXIT
    '';
  };

  healthyThresholds = {
    mode = "absolute";
    steps = [
      {
        color = "red";
        value = null;
      }
      {
        color = "green";
        value = 1;
      }
    ];
  };
  percentThresholds = {
    mode = "absolute";
    steps = [
      {
        color = "green";
        value = null;
      }
      {
        color = "orange";
        value = 70;
      }
      {
        color = "red";
        value = 85;
      }
    ];
  };
  availabilityThresholds = {
    mode = "absolute";
    steps = [
      {
        color = "red";
        value = null;
      }
      {
        color = "orange";
        value = 95;
      }
      {
        color = "green";
        value = 99;
      }
    ];
  };
  uptimeThresholds = {
    mode = "absolute";
    steps = [
      {
        color = "orange";
        value = null;
      }
      {
        color = "green";
        value = 3600;
      }
    ];
  };
  warningThresholds = {
    mode = "absolute";
    steps = [
      {
        color = "green";
        value = null;
      }
      {
        color = "red";
        value = 1;
      }
    ];
  };
  alertWarningThresholds = {
    mode = "absolute";
    steps = [
      {
        color = "green";
        value = null;
      }
      {
        color = "orange";
        value = 1;
      }
    ];
  };
  neutralThresholds = {
    mode = "absolute";
    steps = [
      {
        color = "blue";
        value = null;
      }
    ];
  };
  upMappings = [
    {
      type = "value";
      options = {
        "0" = {
          color = "red";
          index = 0;
          text = "DOWN";
        };
        "1" = {
          color = "green";
          index = 1;
          text = "UP";
        };
      };
    }
  ];
  clearMappings = [
    {
      type = "value";
      options."0" = {
        color = "green";
        index = 0;
        text = "CLEAR";
      };
    }
  ];
  targetMappings = [
    {
      type = "value";
      options = {
        "0" = {
          color = "red";
          index = 0;
          text = "DOWN";
        };
        "1" = {
          color = "gray";
          index = 1;
          text = "OFFLINE";
        };
        "2" = {
          color = "green";
          index = 2;
          text = "UP";
        };
        "3" = {
          color = "gray";
          index = 3;
          text = "N/A";
        };
      };
    }
    {
      type = "special";
      options = {
        match = "null";
        result = {
          color = "gray";
          index = 4;
          text = "N/A";
        };
      };
    }
  ];
  monitoringModeMappings = [
    {
      type = "value";
      options = {
        "0" = {
          color = "gray";
          index = 0;
          text = "DISABLED";
        };
        "1" = {
          color = "blue";
          index = 1;
          text = "OPTIONAL";
        };
        "2" = {
          color = "green";
          index = 2;
          text = "ALWAYS ON";
        };
      };
    }
  ];
  tailnetMappings = [
    {
      type = "value";
      options = {
        "0" = {
          color = "gray";
          index = 0;
          text = "NOT ENROLLED";
        };
        "1" = {
          color = "gray";
          index = 1;
          text = "OFFLINE";
        };
        "2" = {
          color = "green";
          index = 2;
          text = "ONLINE";
        };
      };
    }
  ];
  overallMappings = [
    {
      type = "value";
      options = {
        "0" = {
          color = "red";
          index = 0;
          text = "DOWN";
        };
        "1" = {
          color = "gray";
          index = 1;
          text = "OFFLINE";
        };
        "2" = {
          color = "green";
          index = 2;
          text = "UP";
        };
        "3" = {
          color = "gray";
          index = 3;
          text = "N/A";
        };
      };
    }
  ];
  notAvailableMapping = [
    {
      type = "special";
      options = {
        match = "null";
        result = {
          color = "gray";
          index = 0;
          text = "N/A";
        };
      };
    }
  ];
  freshnessMappings = [
    {
      type = "value";
      options = {
        "0" = {
          color = "blue";
          index = 0;
          text = "BEHIND";
        };
        "1" = {
          color = "orange";
          index = 1;
          text = "LOCAL / UNCOMMITTED";
        };
        "2" = {
          color = "green";
          index = 2;
          text = "CURRENT";
        };
        "3" = {
          color = "gray";
          index = 3;
          text = "UNKNOWN";
        };
      };
    }
  ];
  severityMappings = [
    {
      type = "value";
      options = {
        critical = {
          color = "red";
          index = 0;
          text = "CRITICAL";
        };
        warning = {
          color = "orange";
          index = 1;
          text = "WARNING";
        };
      };
    }
  ];
  configurationFreshnessExpression = ''
    label_replace(
      (
        (
          fleet_nixos_system_info{revision_kind="git"}
          * on(revision) group_left()
          fleet_configuration_main_info
          * 2
        )
        or on(host) (fleet_nixos_system_info{revision_kind="local"} * 0 + 1)
        or on(host) (fleet_nixos_system_info{revision_kind="unknown"} * 0 + 3)
        or on(host) (fleet_nixos_system_info{revision_kind="git"} * 0)
      ),
      "deployed_revision", "$1", "revision", "(.{1,12}).*"
    )
    * on() group_left(main_revision)
    label_replace(fleet_configuration_main_info, "main_revision", "$1", "short_revision", "(.*)")
  '';

  withHost = expression: ''label_replace(${expression}, "host", "$1", "instance", "([^.:]+).*")'';
  failedUnitStates = ''node_systemd_unit_state{job="fleet-node",state="failed"} or fleet_user_systemd_unit_failed{job="fleet-node"}'';
  failedUnitsExpression = withHost ''
    label_replace(node_systemd_unit_state{job="fleet-node",state="failed"} == 1, "manager", "system", "instance", ".*")
    or label_replace(fleet_user_systemd_unit_failed{job="fleet-node"}, "manager", "$1", "user", "(.*)")
  '';
  monitoringPolicyStatusExpression = ''
    label_replace(
      (
        (fleet_monitoring_policy_info{mode="disabled"} * 0)
        or (fleet_monitoring_policy_info{mode="optional"} * 0 + 1)
        or (fleet_monitoring_policy_info{mode="always_on"} * 0 + 2)
      ),
      "signal", "Policy", "host", ".*"
    )
  '';
  tailnetStatusExpression = ''
    label_replace(
      (
        (fleet_tailnet_node_status and on(host) fleet_monitoring_policy_info)
        or on(host) (fleet_monitoring_policy_info * 0)
      ),
      "signal", "Tailnet", "host", ".*"
    )
  '';
  nodeStatusExpression = ''
    label_replace(
      (
        (${withHost ''up{job="fleet-node",always_on="true"}''} * 2)
        or (${withHost ''up{job="fleet-node",always_on="false"}''} + 1)
        or on(host) (fleet_monitoring_policy_info{node="false"} * 0 + 3)
      ),
      "signal", "Node exporter", "host", ".*"
    )
  '';
  smartStatusExpression = ''
    label_replace(
      (
        (${withHost ''up{job="fleet-smartctl",always_on="true"}''} * 2)
        or (${withHost ''up{job="fleet-smartctl",always_on="false"}''} + 1)
        or on(host) (fleet_monitoring_policy_info{smartctl="false"} * 0 + 3)
      ),
      "signal", "SMART exporter", "host", ".*"
    )
  '';
  monitoringStatusExpression = ''
    (${monitoringPolicyStatusExpression})
    or (${tailnetStatusExpression})
    or (${nodeStatusExpression})
    or (${smartStatusExpression})
  '';
  diskStatusExpression = ''
    (
      (
        smartctl_device_smart_status{job="fleet-smartctl"}
        unless on(instance, device) (smartctl_device_critical_warning{job="fleet-smartctl"} > 0)
        unless on(instance, device) (
          smartctl_device_available_spare{job="fleet-smartctl"}
          <= smartctl_device_available_spare_threshold{job="fleet-smartctl"}
        )
        or (smartctl_device_critical_warning{job="fleet-smartctl"} > 0) * 0
        or (
          smartctl_device_available_spare{job="fleet-smartctl"}
          <= smartctl_device_available_spare_threshold{job="fleet-smartctl"}
        ) * 0
      )
      and on(instance) (up{job="fleet-smartctl"} == 1)
      and on(instance, device) (
        timestamp(smartctl_device_smart_status{job="fleet-smartctl"}) > time() - 300
      )
      and on(instance, device) (smartctl_device_smartctl_exit_status{job="fleet-smartctl"} % 8 == 0)
    )
    or on(instance, device) (
      max by(instance, device) (last_over_time(smartctl_device{job="fleet-smartctl"}[24h])) * 0 + 2
    )
  '';
  diskDailyWritesExpression = ''
    (
      smartctl_device_bytes_written{job="fleet-smartctl"}
      - smartctl_device_bytes_written{job="fleet-smartctl"} offset 24h
    )
    and (resets(smartctl_device_bytes_written{job="fleet-smartctl"}[24h]) == 0)
    and on(instance, device) (
      count by(instance, device) (
        count by(instance, device, serial_number) (
          last_over_time(smartctl_device{job="fleet-smartctl"}[24h])
        )
      ) == 1
    )
    and on(instance, device) ((${diskStatusExpression}) != 2)
  '';
  diskHealthExpression = ''
    label_join(
      label_replace(
        (
          label_replace((${diskStatusExpression}), "reading", "Health", "__name__", ".*")
          or label_replace(smartctl_device_temperature{job="fleet-smartctl",temperature_type="current"}, "reading", "Temp", "__name__", ".*")
          or label_replace(smartctl_device_percentage_used{job="fleet-smartctl"}, "reading", "Used", "__name__", ".*")
          or label_replace(smartctl_device_available_spare{job="fleet-smartctl"}, "reading", "Spare", "__name__", ".*")
          or label_replace(smartctl_device_media_errors{job="fleet-smartctl"}, "reading", "Errors", "__name__", ".*")
          or label_replace((${diskDailyWritesExpression}), "reading", "Writes/d", "__name__", ".*")
          or on(instance, device, reading) label_replace((${diskStatusExpression}) * 0 - 1, "reading", "Writes/d", "__name__", ".*")
        ),
        "host", "$1", "instance", "([^.:]+).*"
      ),
      "disk", " / ", "host", "device"
    )
  '';
  activeAlertAge =
    selector:
    ''(time() - ALERTS_FOR_STATE{${selector}}) * ignoring(alertstate) ALERTS{alertstate="firing",${selector}}'';
  activeAlertsExpression = ''
    sort(
      label_replace(
        label_join(
          label_replace(
            label_replace(
              label_replace(
                label_replace(
                  (
                    label_replace(${activeAlertAge ''severity=~"critical|warning",host=""''}, "host", "$1", "instance", "([^.:]+).*")
                    or ${activeAlertAge ''severity=~"critical|warning",host!=""''}
                  ),
                  "resource", "wave $1", "wave", "(.+)"
                ),
                "resource", "partition $1", "partition", "(.+)"
              ),
              "resource", "$1", "device", "(.+)"
            ),
            "resource", "$1", "mountpoint", "(.+)"
          ),
          "where", " ", "host", "resource"
        ),
        "where", "$1", "where", "\\s*(.*?)\\s*"
      )
    )
  '';

  fleetUid = "fleet-revisions";
  fleetCpuPanel = 9;
  fleetMemoryPanel = 10;
  fleetRootPanel = 11;
  fleetDiskHealthPanel = 17;
  fleetConnectivityPanel = 28;
  fleetFailedUnitsPanel = 33;
  fleetLogsUid = "fleet-logs";
  serviceFailuresUid = "service-failures";
  alertmanagerUrl = "http://100.64.0.1:${toString config.services.cluster-alertmanager.listenPort}/";
  vmalertUrl = "http://100.64.0.1:${toString config.services.cluster-vmalert.listenPort}/";

  mkPanelLink =
    {
      uid,
      panel,
      title,
    }:
    {
      inherit title;
      url = "/d/${uid}?viewPanel=${toString panel}&\${__url_time_range}";
      targetBlank = false;
    };
  mkDashboardLink =
    {
      uid,
      title,
      host ? ".*",
      manager ? ".*",
      unit ? ".*",
      timeRange ? "\${__url_time_range}",
    }:
    {
      inherit title;
      url = "/d/${uid}?var-host=${host}&var-manager=${manager}&var-unit=${unit}&${timeRange}";
      targetBlank = false;
    };
  mkHostLogsLink =
    host:
    mkDashboardLink {
      uid = fleetLogsUid;
      title = "Show this host's journal";
      inherit host;
    };
  mkFailureLink =
    host:
    mkDashboardLink {
      uid = serviceFailuresUid;
      title = "Show failed units and failure messages";
      inherit host;
      timeRange = "from=now-30d&to=now";
    };
  mkExploreLink = source: targets: {
    title = "Inspect the source queries in Explore";
    targetBlank = false;
    url =
      let
        variables = [
          "\${datasource}"
          "\${__from}"
          "\${__to}"
        ];
        replacements = [
          "\${datasource:percentencode}"
          "\${__from}"
          "\${__to}"
        ];
        panes = builtins.toJSON {
          A = {
            datasource = source.uid;
            queries = map (target: target // { datasource = source; }) targets;
            range = {
              from = "\${__from}";
              to = "\${__to}";
            };
          };
        };
      in
      "/explore?schemaVersion=1&panes="
      + lib.replaceStrings (map lib.escapeURL variables) replacements (lib.escapeURL panes);
  };
  mkFieldLinks = name: links: {
    matcher = {
      id = "byName";
      options = name;
    };
    properties = [
      {
        id = "links";
        value = links;
      }
    ];
  };
  mkExternalLink =
    {
      title,
      url,
    }:
    {
      inherit title url;
      targetBlank = true;
    };
  mkAlertmanagerLink =
    {
      title,
      matchers,
    }:
    mkExternalLink {
      inherit title;
      url = "${alertmanagerUrl}#/alerts?filter=${lib.escapeURL "{${matchers}}"}";
    };
  slurmAlertLinks = [
    (mkAlertmanagerLink {
      title = "Show the Slurm alerts";
      matchers = ''alertgroup="slurm"'';
    })
    (mkDashboardLink {
      uid = fleetLogsUid;
      title = "Show Slurm controller and worker messages";
      manager = "system";
      unit = lib.escapeURL "slurmctld.service|slurmd.service";
    })
  ];
  fleetDashboardLinks = [
    {
      asDropdown = false;
      icon = "dashboard";
      includeVars = false;
      keepTime = true;
      tags = [ "fleet" ];
      targetBlank = false;
      title = "Fleet dashboards";
      tooltip = "";
      type = "dashboards";
      url = "";
    }
  ];
  mkSeriesColor = name: color: {
    matcher = {
      id = "byName";
      options = name;
    };
    properties = [
      {
        id = "color";
        value = {
          mode = "fixed";
          fixedColor = color;
        };
      }
    ];
  };
  mkTarget =
    {
      expression,
      legend,
      refId,
      instant ? false,
      format ? "time_series",
    }:
    {
      inherit
        datasource
        refId
        format
        ;
      editorMode = "code";
      expr = expression;
      legendFormat = legend;
      range = !instant;
      inherit instant;
    };
  mkRow =
    {
      id,
      title,
      y,
    }:
    {
      inherit id title;
      type = "row";
      collapsed = false;
      panels = [ ];
      gridPos = {
        h = 1;
        w = 24;
        x = 0;
        inherit y;
      };
    };
  mkStat =
    {
      id,
      title,
      expression,
      x,
      y,
      w ? 4,
      unit ? "short",
      decimals ? 0,
      min ? null,
      max ? null,
      thresholds ? percentThresholds,
      mappings ? [ ],
      colorMode ? "background",
      textMode ? "auto",
      legend ? "",
      links ? [ ],
      description ? "",
    }:
    {
      inherit
        id
        title
        description
        datasource
        ;
      type = "stat";
      gridPos = {
        h = 4;
        inherit w x y;
      };
      fieldConfig = {
        defaults = {
          inherit
            unit
            decimals
            min
            max
            thresholds
            mappings
            ;
          links =
            links
            ++ lib.optionals (lib.hasInfix "{{host}}" legend) [
              (mkHostLogsLink "\${__field.labels.host:percentencode}")
            ]
            ++ [
              (mkExploreLink datasource [
                {
                  expr = expression;
                  refId = "A";
                }
              ])
            ];
        };
        overrides = [ ];
      };
      options = {
        inherit colorMode textMode;
        graphMode = "area";
        justifyMode = "auto";
        orientation = "auto";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        showPercentChange = false;
        wideLayout = true;
      };
      targets = [
        (mkTarget {
          inherit expression legend;
          refId = "A";
          instant = true;
        })
      ];
    };
  mkTimeSeries =
    {
      id,
      title,
      targets,
      x,
      y,
      w,
      unit,
      min ? null,
      max ? null,
      links ? [ ],
      overrides ? [ ],
      description ? "",
    }:
    {
      inherit
        id
        title
        description
        datasource
        targets
        ;
      type = "timeseries";
      gridPos = {
        h = 8;
        inherit w x y;
      };
      fieldConfig = {
        defaults = {
          inherit unit min max;
          links =
            links
            ++ lib.optionals (lib.any (target: lib.hasInfix "{{host}}" target.legendFormat) targets) [
              (mkHostLogsLink "\${__field.labels.host:percentencode}")
            ]
            ++ [ (mkExploreLink datasource targets) ];
          color.mode = "palette-classic";
          custom = {
            axisCenteredZero = false;
            axisColorMode = "text";
            axisLabel = "";
            axisPlacement = "auto";
            drawStyle = "line";
            fillOpacity = 18;
            gradientMode = "none";
            lineInterpolation = "smooth";
            lineWidth = 2;
            pointSize = 4;
            scaleDistribution.type = "linear";
            showPoints = "never";
            spanNulls = false;
            stacking = {
              group = "A";
              mode = "none";
            };
            thresholdsStyle.mode = "off";
          };
          thresholds = percentThresholds;
        };
        inherit overrides;
      };
      options = {
        legend = {
          calcs = [ "lastNotNull" ];
          displayMode = "table";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          hideZeros = false;
          mode = "multi";
          sort = "desc";
        };
      };
    };
  mkBarGauge =
    {
      id,
      title,
      expression,
      legend,
      x,
      y,
      w,
      unit ? "short",
      decimals ? null,
      min ? null,
      max ? null,
      thresholds ? percentThresholds,
      mappings ? [ ],
      displayMode ? "gradient",
      links ? [ ],
      description ? "",
    }:
    {
      inherit
        id
        title
        description
        datasource
        ;
      type = "bargauge";
      gridPos = {
        h = 8;
        inherit w x y;
      };
      fieldConfig = {
        defaults = {
          inherit
            unit
            decimals
            min
            max
            thresholds
            mappings
            ;
          links = links ++ [
            (mkHostLogsLink "\${__field.labels.host:percentencode}")
            (mkExploreLink datasource [
              {
                expr = expression;
                refId = "A";
              }
            ])
          ];
        };
        overrides = [ ];
      };
      options = {
        inherit displayMode;
        maxVizHeight = 300;
        minVizHeight = 16;
        minVizWidth = 8;
        namePlacement = "auto";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        showUnfilled = true;
        sizing = "auto";
        valueMode = "color";
      };
      targets = [
        (mkTarget {
          inherit expression legend;
          refId = "A";
          instant = true;
        })
      ];
    };
  mkTable =
    {
      id,
      title,
      description,
      expression,
      x,
      y,
      w,
      fields,
      renamedFields,
      h ? 7,
      overrides ? [ ],
      sortBy ? [ ],
      links ? [ ],
      transformations ? [ ],
    }:
    {
      inherit
        id
        title
        description
        datasource
        ;
      type = "table";
      gridPos = {
        inherit
          h
          w
          x
          y
          ;
      };
      fieldConfig = {
        defaults.links = links ++ [
          (mkExploreLink datasource [
            {
              expr = expression;
              refId = "A";
            }
          ])
        ];
        overrides =
          overrides
          ++ lib.optionals ((renamedFields.host or "") == "Host") [
            (mkFieldLinks "Host" [ (mkHostLogsLink "\${__data.fields[\"Host\"]:percentencode}") ])
          ];
      };
      options = {
        inherit sortBy;
        cellHeight = "sm";
        showHeader = true;
        footer.show = false;
      };
      targets = [
        (mkTarget {
          inherit expression;
          legend = "__auto";
          refId = "A";
          instant = true;
          format = "table";
        })
      ];
      transformations = [
        {
          id = "labelsToFields";
          options.mode = "columns";
        }
        {
          id = "filterFieldsByName";
          options.include.names = lib.attrNames fields;
        }
        {
          id = "organize";
          options = {
            indexByName = fields;
            renameByName = renamedFields;
          };
        }
      ]
      ++ transformations;
    };
  mkAlertsTable =
    {
      id,
      y,
      h,
    }:
    mkTable {
      inherit id y h;
      title = "Active alerts";
      description = "Firing alerts, critical first. Click an alert for its details and silences.";
      expression = activeAlertsExpression;
      x = 0;
      w = 24;
      fields = {
        severity = 0;
        alertname = 1;
        where = 2;
        Value = 3;
      };
      renamedFields = {
        severity = "Severity";
        alertname = "Alert";
        where = "Where";
        Value = "Firing for";
      };
      sortBy = [
        {
          displayName = "Severity";
          desc = false;
        }
      ];
      overrides = [
        {
          matcher = {
            id = "byName";
            options = "Severity";
          };
          properties = [
            {
              id = "mappings";
              value = severityMappings;
            }
            {
              id = "custom.cellOptions";
              value = {
                mode = "basic";
                type = "color-background";
              };
            }
            {
              id = "custom.width";
              value = 110;
            }
          ];
        }
        {
          matcher = {
            id = "byName";
            options = "Alert";
          };
          properties = [
            {
              id = "links";
              value = [
                (mkExternalLink {
                  title = "Show the alert in Alertmanager";
                  url = "${alertmanagerUrl}#/alerts?filter=${lib.escapeURL "{alertname=\""}\${__value.raw}${lib.escapeURL "\"}"}";
                })
              ];
            }
          ];
        }
        {
          matcher = {
            id = "byName";
            options = "Firing for";
          };
          properties = [
            {
              id = "unit";
              value = "dtdurations";
            }
            {
              id = "decimals";
              value = 0;
            }
            {
              id = "custom.width";
              value = 200;
            }
          ];
        }
      ];
    };

  dashboard = pkgs.writeText "fleet-overview.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "Operational health, capacity, storage, disk health, and deployment state for the managed fleet.";
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = fleetDashboardLinks;
      liveNow = false;
      panels = [
        (mkRow {
          id = 1;
          title = "Fleet At A Glance";
          y = 0;
        })
        (mkStat {
          id = 2;
          title = "Unreachable hosts";
          expression = "count(count by(host) (${withHost ''up{job=~"fleet-(node|smartctl)",always_on="true"} == 0''})) or vector(0)";
          x = 0;
          y = 1;
          min = 0;
          thresholds = warningThresholds;
          mappings = clearMappings;
          links = [
            (mkPanelLink {
              uid = fleetUid;
              panel = fleetConnectivityPanel;
              title = "Show the hosts";
            })
          ];
          description = "Always-on hosts with an exporter down. Click for the host table.";
        })
        (mkStat {
          id = 3;
          title = "Highest CPU";
          expression = "topk(1, ${withHost ''(1 - avg by(instance) (rate(node_cpu_seconds_total{job="fleet-node",mode="idle"}[5m]))) * 100''})";
          legend = "{{host}}";
          textMode = "value_and_name";
          x = 4;
          y = 1;
          unit = "percent";
          decimals = 1;
          min = 0;
          max = 100;
          links = [
            (mkPanelLink {
              uid = fleetUid;
              panel = fleetCpuPanel;
              title = "Show the history of all hosts";
            })
          ];
          description = "Busiest host, last 5 minutes. Click for all hosts.";
        })
        (mkStat {
          id = 4;
          title = "Highest memory";
          expression = "topk(1, ${withHost ''(1 - node_memory_MemAvailable_bytes{job="fleet-node"} / node_memory_MemTotal_bytes{job="fleet-node"}) * 100''})";
          legend = "{{host}}";
          textMode = "value_and_name";
          x = 8;
          y = 1;
          unit = "percent";
          decimals = 1;
          min = 0;
          max = 100;
          links = [
            (mkPanelLink {
              uid = fleetUid;
              panel = fleetMemoryPanel;
              title = "Show the history of all hosts";
            })
          ];
          description = "Click for all hosts.";
        })
        (mkStat {
          id = 5;
          title = "Highest root usage";
          expression = "topk(1, ${withHost ''(1 - node_filesystem_avail_bytes{job="fleet-node",mountpoint="/"} / node_filesystem_size_bytes{job="fleet-node",mountpoint="/"}) * 100''})";
          legend = "{{host}}";
          textMode = "value_and_name";
          x = 12;
          y = 1;
          unit = "percent";
          decimals = 1;
          min = 0;
          max = 100;
          links = [
            (mkPanelLink {
              uid = fleetUid;
              panel = fleetRootPanel;
              title = "Show the history of all hosts";
            })
          ];
          description = "Click for all hosts.";
        })
        (mkStat {
          id = 6;
          title = "Failing disks";
          expression = "count((${diskStatusExpression}) == 0) or vector(0)";
          x = 16;
          y = 1;
          min = 0;
          thresholds = warningThresholds;
          mappings = clearMappings;
          links = [
            (mkPanelLink {
              uid = fleetUid;
              panel = fleetDiskHealthPanel;
              title = "Show the disks";
            })
          ];
          description = "Disks with Health FAIL. Click for the disk table.";
        })
        (mkStat {
          id = 7;
          title = "Failed services";
          expression = "sum(${failedUnitStates})";
          x = 20;
          y = 1;
          thresholds = warningThresholds;
          mappings = clearMappings;
          links = [
            (mkDashboardLink {
              uid = serviceFailuresUid;
              title = "Show failed units and failure messages";
              timeRange = "from=now-30d&to=now";
            })
          ];
          description = "Failed system and user units. Click for units and journal messages that explain each failure.";
        })
        (mkAlertsTable {
          id = 47;
          y = 5;
          h = 8;
        })

        {
          id = fleetConnectivityPanel;
          title = "Fleet Connectivity And Monitoring";
          description = "Tailnet reports Headscale node state; exporter columns report metric reachability. Disabled exporters are N/A, and optional failures do not degrade fleet health.";
          type = "table";
          inherit datasource;
          gridPos = {
            h = 8;
            w = 24;
            x = 0;
            y = 13;
          };
          fieldConfig = {
            defaults.links = [
              (mkExploreLink datasource [
                {
                  expr = monitoringStatusExpression;
                  refId = "A";
                }
              ])
            ];
            overrides = [
              (mkFieldLinks "Host" [ (mkHostLogsLink "\${__data.fields[\"Host\"]:percentencode}") ])
              {
                matcher = {
                  id = "byName";
                  options = "Policy";
                };
                properties = [
                  {
                    id = "mappings";
                    value = monitoringModeMappings;
                  }
                  {
                    id = "custom.cellOptions";
                    value = {
                      mode = "basic";
                      type = "color-background";
                    };
                  }
                ];
              }
              {
                matcher = {
                  id = "byName";
                  options = "Tailnet";
                };
                properties = [
                  {
                    id = "mappings";
                    value = tailnetMappings;
                  }
                  {
                    id = "custom.cellOptions";
                    value = {
                      mode = "basic";
                      type = "color-background";
                    };
                  }
                ];
              }
            ]
            ++
              map
                (name: {
                  matcher = {
                    id = "byName";
                    options = name;
                  };
                  properties = [
                    {
                      id = "mappings";
                      value = targetMappings;
                    }
                    {
                      id = "custom.cellOptions";
                      value = {
                        mode = "basic";
                        type = "color-background";
                      };
                    }
                  ];
                })
                [
                  "Node exporter"
                  "SMART exporter"
                ]
            ++ [
              {
                matcher = {
                  id = "byName";
                  options = "Overall";
                };
                properties = [
                  {
                    id = "mappings";
                    value = overallMappings;
                  }
                  {
                    id = "custom.cellOptions";
                    value = {
                      mode = "basic";
                      type = "color-background";
                    };
                  }
                  {
                    id = "custom.width";
                    value = 170;
                  }
                ];
              }
            ];
          };
          options = {
            cellHeight = "sm";
            showHeader = true;
            footer.show = false;
          };
          targets = [
            (mkTarget {
              expression = monitoringStatusExpression;
              legend = "__auto";
              refId = "A";
              instant = true;
              format = "table";
            })
          ];
          transformations = [
            {
              id = "labelsToFields";
              options.mode = "columns";
            }
            {
              id = "groupingToMatrix";
              options = {
                columnField = "signal";
                rowField = "host";
                valueField = "Value";
                emptyValue = "null";
              };
            }
            {
              id = "calculateField";
              options = {
                alias = "Overall";
                mode = "reduceRow";
                reduce = {
                  include = [
                    "Node exporter"
                    "SMART exporter"
                  ];
                  reducer = "min";
                  nullValueMode = "ignore";
                };
                replaceFields = false;
                timeSeries = false;
              };
            }
            {
              id = "organize";
              options = {
                indexByName = {
                  "host\\signal" = 0;
                  Policy = 1;
                  Tailnet = 2;
                  "Node exporter" = 3;
                  "SMART exporter" = 4;
                  Overall = 5;
                };
                renameByName = {
                  "host\\signal" = "Host";
                };
              };
            }
          ];
        }

        (mkRow {
          id = 8;
          title = "Host Resources";
          y = 21;
        })
        (mkTimeSeries {
          id = fleetCpuPanel;
          title = "CPU Utilization";
          x = 0;
          y = 22;
          w = 8;
          unit = "percent";
          min = 0;
          max = 100;
          targets = [
            (mkTarget {
              expression = withHost ''(1 - avg by(instance) (rate(node_cpu_seconds_total{job="fleet-node",mode="idle"}[$__rate_interval]))) * 100'';
              legend = "{{host}}";
              refId = "A";
            })
          ];
        })
        (mkTimeSeries {
          id = fleetMemoryPanel;
          title = "Memory Utilization";
          x = 8;
          y = 22;
          w = 8;
          unit = "percent";
          min = 0;
          max = 100;
          targets = [
            (mkTarget {
              expression = withHost ''(1 - node_memory_MemAvailable_bytes{job="fleet-node"} / node_memory_MemTotal_bytes{job="fleet-node"}) * 100'';
              legend = "{{host}}";
              refId = "A";
            })
          ];
        })
        (mkTimeSeries {
          id = fleetRootPanel;
          title = "Root Filesystem Utilization";
          x = 16;
          y = 22;
          w = 8;
          unit = "percent";
          min = 0;
          max = 100;
          targets = [
            (mkTarget {
              expression = withHost ''(1 - node_filesystem_avail_bytes{job="fleet-node",mountpoint="/"} / node_filesystem_size_bytes{job="fleet-node",mountpoint="/"}) * 100'';
              legend = "{{host}}";
              refId = "A";
            })
          ];
        })

        (mkRow {
          id = 12;
          title = "Traffic And I/O";
          y = 30;
        })
        (mkTimeSeries {
          id = 13;
          title = "Network Throughput";
          x = 0;
          y = 31;
          w = 12;
          unit = "Bps";
          min = 0;
          targets = [
            (mkTarget {
              expression = withHost ''sum by(instance) (rate(node_network_receive_bytes_total{job="fleet-node",device!~"lo|veth.*|docker.*|virbr.*"}[$__rate_interval]))'';
              legend = "{{host}} receive";
              refId = "A";
            })
            (mkTarget {
              expression = withHost ''sum by(instance) (rate(node_network_transmit_bytes_total{job="fleet-node",device!~"lo|veth.*|docker.*|virbr.*"}[$__rate_interval]))'';
              legend = "{{host}} transmit";
              refId = "B";
            })
          ];
        })
        (mkTimeSeries {
          id = 14;
          title = "Physical Disk Throughput";
          x = 12;
          y = 31;
          w = 12;
          unit = "Bps";
          min = 0;
          description = "Device-mapper, loop, and zram devices are excluded to avoid double counting.";
          targets = [
            (mkTarget {
              expression = withHost ''sum by(instance) (rate(node_disk_read_bytes_total{job="fleet-node",device!~"dm-.*|loop.*|zram.*"}[$__rate_interval]))'';
              legend = "{{host}} read";
              refId = "A";
            })
            (mkTarget {
              expression = withHost ''sum by(instance) (rate(node_disk_written_bytes_total{job="fleet-node",device!~"dm-.*|loop.*|zram.*"}[$__rate_interval]))'';
              legend = "{{host}} write";
              refId = "B";
            })
          ];
        })

        (mkRow {
          id = 15;
          title = "Storage And Disk Health";
          y = 39;
        })
        (mkBarGauge {
          id = 16;
          title = "Filesystem Usage";
          expression = withHost ''100 * (1 - node_filesystem_avail_bytes{job="fleet-node",mountpoint=~"/|/boot|/home"} / node_filesystem_size_bytes{job="fleet-node",mountpoint=~"/|/boot|/home"})'';
          legend = "{{host}}  {{mountpoint}}";
          x = 0;
          y = 40;
          w = 8;
          unit = "percent";
          min = 0;
          max = 100;
          description = "Usage for root, boot, and dedicated home filesystems.";
        })
        {
          id = fleetDiskHealthPanel;
          title = "Physical Disk Health";
          description = "Physical disk health, NVMe endurance consumed, and host writes over the last 24 hours. Errors are reported media/data-integrity errors, not a NAND bad-block count. Hosts without SMART access do not appear here.";
          type = "table";
          inherit datasource;
          gridPos = {
            h = 8;
            w = 16;
            x = 8;
            y = 40;
          };
          fieldConfig = {
            defaults = {
              links = [
                (mkExploreLink datasource [
                  {
                    expr = diskHealthExpression;
                    refId = "A";
                  }
                ])
              ];
              decimals = 0;
              noValue = "N/A";
              mappings = notAvailableMapping;
              custom = {
                align = "center";
                minWidth = 50;
                width = 65;
              };
            };
            overrides = [
              {
                matcher = {
                  id = "byName";
                  options = "Host / Disk";
                };
                properties = [
                  {
                    id = "custom.width";
                    value = 230;
                  }
                  {
                    id = "custom.align";
                    value = "left";
                  }
                ];
              }
              {
                matcher = {
                  id = "byName";
                  options = "Health";
                };
                properties = [
                  {
                    id = "description";
                    value = "SMART status and NVMe critical warnings. FAIL also indicates spare capacity at or below the device threshold. UNKNOWN means missing, failed, or more than five-minute-old exporter data.";
                  }
                  {
                    id = "custom.width";
                    value = 95;
                  }
                  {
                    id = "mappings";
                    value = [
                      {
                        type = "value";
                        options = {
                          "0" = {
                            color = "red";
                            text = "FAIL";
                          };
                          "1" = {
                            color = "green";
                            text = "OK";
                          };
                          "2" = {
                            color = "gray";
                            text = "UNKNOWN";
                          };
                        };
                      }
                      {
                        type = "special";
                        options = {
                          match = "null";
                          result = {
                            color = "gray";
                            text = "UNKNOWN";
                          };
                        };
                      }
                    ];
                  }
                  {
                    id = "custom.cellOptions";
                    value = {
                      mode = "basic";
                      type = "color-background";
                    };
                  }
                ];
              }
              {
                matcher = {
                  id = "byName";
                  options = "Temp";
                };
                properties = [
                  {
                    id = "description";
                    value = "Current disk temperature.";
                  }
                  {
                    id = "unit";
                    value = "celsius";
                  }
                  {
                    id = "mappings";
                    value = notAvailableMapping;
                  }
                  {
                    id = "thresholds";
                    value = {
                      mode = "absolute";
                      steps = [
                        {
                          color = "green";
                          value = null;
                        }
                        {
                          color = "orange";
                          value = 55;
                        }
                        {
                          color = "red";
                          value = 70;
                        }
                      ];
                    };
                  }
                  {
                    id = "custom.cellOptions";
                    value = {
                      mode = "basic";
                      type = "color-background";
                    };
                  }
                ];
              }
              {
                matcher = {
                  id = "byName";
                  options = "Used";
                };
                properties = [
                  {
                    id = "description";
                    value = "NVMe Percentage Used: manufacturer estimate of endurance consumed, not filesystem usage. Can exceed 100%; not a failure-date prediction.";
                  }
                  {
                    id = "unit";
                    value = "percent";
                  }
                  {
                    id = "mappings";
                    value = notAvailableMapping;
                  }
                  {
                    id = "thresholds";
                    value = {
                      mode = "absolute";
                      steps = [
                        {
                          color = "green";
                          value = null;
                        }
                        {
                          color = "orange";
                          value = 90;
                        }
                        {
                          color = "red";
                          value = 100;
                        }
                      ];
                    };
                  }
                  {
                    id = "custom.cellOptions";
                    value.type = "color-text";
                  }
                ];
              }
              {
                matcher = {
                  id = "byName";
                  options = "Spare";
                };
                properties = [
                  {
                    id = "description";
                    value = "NVMe available spare capacity. Health reports FAIL at or below this disk's manufacturer threshold.";
                  }
                  {
                    id = "unit";
                    value = "percent";
                  }
                  {
                    id = "mappings";
                    value = notAvailableMapping;
                  }
                ];
              }
              {
                matcher = {
                  id = "byName";
                  options = "Writes/d";
                };
                properties = [
                  {
                    id = "description";
                    value = "Host bytes written over the last 24 hours, in decimal units. N/A until a full day of history exists, after a counter reset or disk replacement, or when SMART data is unavailable.";
                  }
                  {
                    id = "custom.width";
                    value = 90;
                  }
                  {
                    id = "decimals";
                    value = 1;
                  }
                  {
                    id = "unit";
                    value = "decbytes";
                  }
                  {
                    id = "mappings";
                    value = notAvailableMapping ++ [
                      {
                        type = "value";
                        options = {
                          "-1" = {
                            color = "gray";
                            text = "N/A";
                          };
                        };
                      }
                    ];
                  }
                ];
              }
              {
                matcher = {
                  id = "byName";
                  options = "Errors";
                };
                properties = [
                  {
                    id = "description";
                    value = "Lifetime NVMe media and data-integrity errors. Zero means none reported. Nonzero counts are highlighted; this is not a count of internally retired NAND blocks.";
                  }
                  {
                    id = "thresholds";
                    value = warningThresholds;
                  }
                  {
                    id = "custom.cellOptions";
                    value = {
                      mode = "basic";
                      type = "color-background";
                    };
                  }
                ];
              }
            ];
          };
          options = {
            cellHeight = "sm";
            showHeader = true;
            footer.show = false;
          };
          targets = [
            (mkTarget {
              expression = diskHealthExpression;
              legend = "__auto";
              refId = "A";
              instant = true;
              format = "table";
            })
          ];
          transformations = [
            {
              id = "labelsToFields";
              options.mode = "columns";
            }
            {
              id = "groupingToMatrix";
              options = {
                columnField = "reading";
                rowField = "disk";
                valueField = "Value";
                emptyValue = "null";
              };
            }
            {
              id = "organize";
              options = {
                indexByName = {
                  "disk\\reading" = 0;
                  Health = 1;
                  Temp = 2;
                  Used = 3;
                  Spare = 4;
                  Errors = 5;
                  "Writes/d" = 6;
                };
                renameByName."disk\\reading" = "Host / Disk";
              };
            }
          ];
        }

        (mkRow {
          id = 21;
          title = "System State";
          y = 48;
        })
        (mkBarGauge {
          id = 29;
          title = "Availability";
          description = "Share of the time range in which the node exporter answered. Always-on hosts only.";
          expression = withHost ''avg_over_time(up{job="fleet-node",always_on="true"}[$__range]) * 100'';
          legend = "{{host}}";
          x = 0;
          y = 49;
          w = 8;
          unit = "percent";
          decimals = 2;
          min = 0;
          max = 100;
          thresholds = availabilityThresholds;
          displayMode = "basic";
        })
        (mkBarGauge {
          id = 22;
          title = "Uptime";
          description = "Time since last boot.";
          expression = withHost ''time() - node_boot_time_seconds{job="fleet-node"}'';
          legend = "{{host}}";
          x = 8;
          y = 49;
          w = 8;
          unit = "s";
          min = 0;
          thresholds = uptimeThresholds;
          displayMode = "basic";
        })
        (mkBarGauge {
          id = 24;
          title = "Failed Systemd Units";
          description = "Failed system and owner user units per host. Click a host's bar for its failed units and failure messages.";
          expression = withHost "sum by(instance) (${failedUnitStates})";
          legend = "{{host}}";
          x = 16;
          y = 49;
          w = 8;
          min = 0;
          thresholds = warningThresholds;
          mappings = clearMappings;
          displayMode = "basic";
          links = [ (mkFailureLink "\${__field.labels.host:percentencode}") ];
        })
        (mkTimeSeries {
          id = 23;
          title = "System Load";
          x = 0;
          y = 57;
          w = 24;
          unit = "short";
          min = 0;
          targets = [
            (mkTarget {
              expression = withHost ''node_load1{job="fleet-node"}'';
              legend = "{{host}} load 1m";
              refId = "A";
            })
            (mkTarget {
              expression = withHost ''node_load5{job="fleet-node"}'';
              legend = "{{host}} load 5m";
              refId = "B";
            })
          ];
        })
        (mkTable {
          id = fleetFailedUnitsPanel;
          title = "Failed Units";
          description = "Current failed system and owner user units. Click a unit for its journal, including application errors and exit results. Failure state can remain after the original event leaves this dashboard's time range.";
          expression = failedUnitsExpression;
          x = 0;
          y = 65;
          w = 24;
          fields = {
            host = 0;
            manager = 1;
            name = 2;
          };
          renamedFields = {
            host = "Host";
            manager = "Manager";
            name = "Unit";
          };
          overrides = [
            (mkFieldLinks "Unit" [
              (mkDashboardLink {
                uid = serviceFailuresUid;
                title = "Show this unit's failure messages and journal";
                host = "\${__data.fields[\"Host\"]:percentencode}";
                manager = "\${__data.fields[\"Manager\"]:percentencode}";
                unit = "\${__data.fields[\"Unit\"]:percentencode}";
                timeRange = "from=now-30d&to=now";
              })
            ])
          ];
        })

        (mkRow {
          id = 25;
          title = "Configuration Source";
          y = 72;
        })
        (mkTable {
          id = 26;
          title = "Configuration Freshness";
          description = "Deployed source compared with dotfiles main. BEHIND is normal during a rollout. Path and dirty-tree builds show as local.";
          expression = configurationFreshnessExpression;
          x = 0;
          y = 73;
          w = 24;
          fields = {
            host = 0;
            deployed_revision = 1;
            main_revision = 2;
            Value = 3;
            version = 4;
          };
          renamedFields = {
            host = "Host";
            deployed_revision = "Deployed source";
            main_revision = "Desired main";
            Value = "Status";
            version = "NixOS version";
          };
          overrides = [
            {
              matcher = {
                id = "byName";
                options = "Status";
              };
              properties = [
                {
                  id = "mappings";
                  value = freshnessMappings;
                }
                {
                  id = "custom.cellOptions";
                  value = {
                    mode = "basic";
                    type = "color-background";
                  };
                }
                {
                  id = "custom.width";
                  value = 190;
                }
              ];
            }
          ];
        })
        (mkRow {
          id = 34;
          title = "Deployment";
          y = 80;
        })
        (mkTable {
          id = 35;
          title = "Upgrade State";
          description = "Latest fleet-upgrade run per host. held: local generation or inventory hold. waiting: the rollout has not reached the host.";
          expression = ''label_replace(fleet_upgrade_state == 1, "target", "$1", "revision", "(.{0,12}).*")'';
          x = 0;
          y = 81;
          w = 12;
          fields = {
            host = 0;
            state = 1;
            reason = 2;
            target = 3;
          };
          renamedFields = {
            host = "Host";
            state = "State";
            reason = "Reason";
            target = "Target";
          };
        })
        (mkTable {
          id = 36;
          title = "Reboot Required";
          description = "Boot components that change at the next reboot.";
          expression = "fleet_nixos_reboot_required == 1";
          x = 12;
          y = 81;
          w = 12;
          fields = {
            host = 0;
            component = 1;
          };
          renamedFields = {
            host = "Host";
            component = "Changed component";
          };
        })
        (mkTable {
          id = 37;
          title = "Rollout Waves";
          description = "Revision approved for each wave and the state of the gate to the next deploy revision. A wave takes a revision after the previous wave ran it without failed units for the soak time.";
          expression = ''
            label_replace(
              label_replace(fleet_deploy_wave_info, "approved", "$1", "revision", "(.{0,12}).*"),
              "next", "$1", "candidate", "(.{0,12}).*"
            )
          '';
          x = 0;
          y = 88;
          w = 24;
          fields = {
            wave = 0;
            approved = 1;
            next = 2;
            state = 3;
          };
          renamedFields = {
            wave = "Wave";
            approved = "Approved";
            next = "Next";
            state = "Gate";
          };
        })
        (mkRow {
          id = 30;
          title = "Tailnet Drift";
          y = 95;
        })
        (mkTable {
          id = 31;
          title = "Missing Tags";
          description = "ACL policy tags the inventory expects that headscale does not have. Promote with 'headscale nodes tag'.";
          expression = ''
            (fleet_expected_tag_info unless on(host, tag) fleet_tailnet_node_tag_info)
            and on() (count(fleet_tailnet_node_tag_info) > 0)
          '';
          x = 0;
          y = 96;
          w = 12;
          fields = {
            host = 0;
            tag = 1;
          };
          renamedFields = {
            host = "Host";
            tag = "Missing tag";
          };
        })
        (mkTable {
          id = 32;
          title = "Unexpected Tags";
          description = "Tags headscale carries that the inventory does not list. Nodes left on tag:bootstrap appear here.";
          expression = "fleet_tailnet_node_tag_info unless on(host, tag) fleet_expected_tag_info";
          x = 12;
          y = 96;
          w = 12;
          fields = {
            host = 0;
            tag = 1;
          };
          renamedFields = {
            host = "Host";
            tag = "Unexpected tag";
          };
        })
        (mkRow {
          id = 38;
          title = "Slurm";
          y = 103;
        })
        (mkStat {
          id = 39;
          title = "Controller";
          description = "Whether the slurmctld metrics endpoint answers. Click for the Slurm alerts.";
          expression = ''max(up{job=~"fleet-slurm-.+"}) or on() vector(0)'';
          x = 0;
          y = 104;
          thresholds = healthyThresholds;
          mappings = upMappings;
          links = slurmAlertLinks;
        })
        (mkStat {
          id = 40;
          title = "Nodes Down";
          description = "Nodes that slurmctld marks down. Run 'sinfo -R' for the reason. Click for the Slurm alerts.";
          expression = "max(slurm_nodes_down)";
          x = 4;
          y = 104;
          thresholds = warningThresholds;
          mappings = clearMappings;
          links = slurmAlertLinks;
        })
        (mkStat {
          id = 41;
          title = "Not Responding";
          description = "Nodes whose slurmd does not answer slurmctld. Click for the Slurm alerts.";
          expression = "max(slurm_nodes_noresp)";
          x = 8;
          y = 104;
          thresholds = warningThresholds;
          mappings = clearMappings;
          links = slurmAlertLinks;
        })
        (mkStat {
          id = 42;
          title = "Drained";
          description = "Nodes that accept no new jobs. Run 'sinfo -R' for the reason. Click for the Slurm alerts.";
          expression = "max(slurm_nodes_drain)";
          x = 12;
          y = 104;
          thresholds = alertWarningThresholds;
          mappings = clearMappings;
          links = slurmAlertLinks;
        })
        (mkStat {
          id = 43;
          title = "Jobs Running";
          expression = "max(slurm_jobs_running)";
          x = 16;
          y = 104;
          colorMode = "none";
          links = [
            (mkPanelLink {
              uid = fleetUid;
              panel = 46;
              title = "Show job history";
            })
          ];
        })
        (mkStat {
          id = 44;
          title = "Jobs Pending";
          expression = "max(slurm_jobs_pending)";
          x = 20;
          y = 104;
          colorMode = "none";
          links = [
            (mkPanelLink {
              uid = fleetUid;
              panel = 46;
              title = "Show job history";
            })
          ];
        })
        (mkTimeSeries {
          id = 45;
          title = "Slurm Nodes";
          description = "Node states over time. A node can be counted in more than one state, for example down and not responding.";
          x = 0;
          y = 108;
          w = 12;
          unit = "short";
          min = 0;
          overrides = [
            (mkSeriesColor "Idle" "blue")
            (mkSeriesColor "Busy" "green")
            (mkSeriesColor "Down" "red")
            (mkSeriesColor "Drained" "orange")
            (mkSeriesColor "Not responding" "dark-red")
          ];
          targets = [
            (mkTarget {
              expression = "max(slurm_nodes_idle)";
              legend = "Idle";
              refId = "A";
            })
            (mkTarget {
              expression = "max(slurm_nodes_alloc) + max(slurm_nodes_mixed)";
              legend = "Busy";
              refId = "B";
            })
            (mkTarget {
              expression = "max(slurm_nodes_down)";
              legend = "Down";
              refId = "C";
            })
            (mkTarget {
              expression = "max(slurm_nodes_drain)";
              legend = "Drained";
              refId = "D";
            })
            (mkTarget {
              expression = "max(slurm_nodes_noresp)";
              legend = "Not responding";
              refId = "E";
            })
          ];
        })
        (mkTimeSeries {
          id = 46;
          title = "Slurm Jobs";
          x = 12;
          y = 108;
          w = 12;
          unit = "short";
          min = 0;
          overrides = [
            (mkSeriesColor "Running" "green")
            (mkSeriesColor "Pending" "blue")
          ];
          targets = [
            (mkTarget {
              expression = "max(slurm_jobs_running)";
              legend = "Running";
              refId = "A";
            })
            (mkTarget {
              expression = "max(slurm_jobs_pending)";
              legend = "Pending";
              refId = "B";
            })
          ];
        })
      ];
      refresh = "30s";
      schemaVersion = 42;
      tags = [
        "fleet"
        "health"
        "storage"
      ];
      templating.list = [
        {
          current = { };
          hide = 2;
          includeAll = false;
          label = "Datasource";
          multi = false;
          name = "datasource";
          options = [ ];
          query = "prometheus";
          refresh = 1;
          regex = "VictoriaMetrics";
          skipUrlSync = false;
          type = "datasource";
        }
      ];
      time = {
        from = "now-6h";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      title = "Fleet Overview";
      uid = fleetUid;
      version = 9;
      weekStart = "";
    }
  );
  alertsDashboard = pkgs.writeText "alerts-overview.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "Read-only vmalert state persisted in VictoriaMetrics; use Alertmanager for silences and routing.";
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = fleetDashboardLinks ++ [
        {
          asDropdown = false;
          icon = "external link";
          includeVars = false;
          keepTime = false;
          tags = [ ];
          targetBlank = true;
          title = "Alertmanager";
          tooltip = "Inspect active alerts, routing, and silences.";
          type = "link";
          url = alertmanagerUrl;
        }
        {
          asDropdown = false;
          icon = "external link";
          includeVars = false;
          keepTime = false;
          tags = [ ];
          targetBlank = true;
          title = "vmalert rules";
          tooltip = "Inspect rule groups, evaluations, and expressions.";
          type = "link";
          url = vmalertUrl;
        }
      ];
      liveNow = false;
      panels = [
        (mkStat {
          id = 1;
          title = "Critical firing";
          expression = ''sum(ALERTS{alertstate="firing",severity="critical"}) or vector(0)'';
          x = 0;
          y = 0;
          w = 6;
          min = 0;
          thresholds = warningThresholds;
          mappings = clearMappings;
          links = [
            (mkAlertmanagerLink {
              title = "Show the critical alerts in Alertmanager";
              matchers = ''severity="critical"'';
            })
          ];
          description = "Click for details in Alertmanager.";
        })
        (mkStat {
          id = 2;
          title = "Warnings firing";
          expression = ''sum(ALERTS{alertstate="firing",severity="warning"}) or vector(0)'';
          x = 6;
          y = 0;
          w = 6;
          min = 0;
          thresholds = alertWarningThresholds;
          mappings = clearMappings;
          links = [
            (mkAlertmanagerLink {
              title = "Show the warnings in Alertmanager";
              matchers = ''severity="warning"'';
            })
          ];
          description = "Click for details in Alertmanager.";
        })
        (mkStat {
          id = 3;
          title = "Pending";
          expression = ''sum(ALERTS{alertstate="pending",severity!="none"}) or vector(0)'';
          x = 12;
          y = 0;
          w = 6;
          min = 0;
          thresholds = neutralThresholds;
          mappings = clearMappings;
          links = [
            (mkExternalLink {
              title = "Show the pending alerts in vmalert";
              url = "${vmalertUrl}vmalert/alerts";
            })
          ];
          description = "Conditions are true, but the hold time is not over. No action yet. Click for vmalert.";
        })
        (mkStat {
          id = 4;
          title = "Alert pipeline";
          expression = ''max(ALERTS{alertstate="firing",alertname="Watchdog"}) or vector(0)'';
          x = 18;
          y = 0;
          w = 6;
          min = 0;
          max = 1;
          thresholds = healthyThresholds;
          mappings = upMappings;
          links = [
            (mkExternalLink {
              title = "Show the rule groups in vmalert";
              url = "${vmalertUrl}vmalert/groups";
            })
          ];
          description = "DOWN means alerting is broken. Click for vmalert.";
        })
        (mkAlertsTable {
          id = 5;
          y = 4;
          h = 9;
        })
        (mkTimeSeries {
          id = 6;
          title = "Firing alerts by severity";
          description = "Historical count of actionable firing alerts from vmalert's persisted state.";
          overrides = [
            (mkSeriesColor "critical" "red")
            (mkSeriesColor "warning" "orange")
          ];
          targets = [
            (mkTarget {
              expression = ''sum by (severity) (ALERTS{alertstate="firing",severity!="none"})'';
              legend = "{{severity}}";
              refId = "A";
            })
          ];
          x = 0;
          y = 13;
          w = 24;
          unit = "short";
          min = 0;
        })
      ];
      refresh = "30s";
      schemaVersion = 42;
      tags = [
        "alerts"
        "fleet"
        "vmalert"
      ];
      templating.list = [
        {
          current = { };
          hide = 2;
          includeAll = false;
          label = "Datasource";
          multi = false;
          name = "datasource";
          options = [ ];
          query = "prometheus";
          refresh = 1;
          regex = "VictoriaMetrics";
          skipUrlSync = false;
          type = "datasource";
        }
      ];
      time = {
        from = "now-24h";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      title = "Alerts Overview";
      uid = "alerts-overview";
      version = 1;
      weekStart = "";
    }
  );
  logsDatasource = {
    type = "victoriametrics-logs-datasource";
    uid = "victorialogs";
  };
  sshAccepted = ''{unit="sshd.service"} _msg:~"^Accepted (publickey|password|keyboard-interactive) for "'';
  sshAcceptedParsed = ''${sshAccepted} | extract_regexp "^Accepted (?P<method>[^ ]+) for (?P<user>[^ ]+) from (?P<source_ip>[^ ]+) port (?P<source_port>[0-9]+) ssh2(?:: (?P<key_type>[^ ]+) (?P<fingerprint>[^ ]+))?$"'';
  sshConnections = ''{unit="sshd.service"} _msg:~"^Connection from " | extract_regexp "^Connection from (?P<source_ip>[^ ]+) port (?P<source_port>[0-9]+) on (?P<destination_ip>[^ ]+) port (?P<destination_port>[0-9]+)"'';
  sshCredentialFailures = ''{unit="sshd.service"} _msg:~"^(Failed |Invalid user |maximum authentication attempts exceeded)"'';
  sshTargetedAccounts = ''{unit="sshd.service"} _msg:~"(Invalid user|authenticating user)" | extract_regexp "(?:Invalid user|authenticating user) (?P<user>[^ ]+) (?:from )?(?P<source_ip>[^ ]+) port"'';
  nonInternetSourcePattern = "^(100[.](6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])[.]|10[.]|127[.]|169[.]254[.]|172[.](1[6-9]|2[0-9]|3[01])[.]|192[.]168[.]|::1$|[fF][cCdD][0-9a-fA-F]{2}:|[fF][eE][89aAbB][0-9a-fA-F]:)";
  sshInternetConnections = ''${sshConnections} | source_ip:!~"${nonInternetSourcePattern}"'';
  sshInternetAccepted = ''${sshAcceptedParsed} | source_ip:!~"${nonInternetSourcePattern}"'';

  sshAccessUid = "ssh-access";
  networkFlowsUid = "network-flows";
  flowsTopSourcesPanel = 3;
  flowsRawPanel = 5;
  sshAcceptedPanel = 9;
  sshConnectionsPanel = 10;
  sshInternetAcceptedPanel = 14;
  sshRejectionsPanel = 15;

  mkLogsTarget =
    {
      expression,
      refId ? "A",
      queryType ? "stats",
      legend ? null,
      maxLines ? null,
      direction ? null,
    }:
    {
      datasource = logsDatasource;
      editorMode = "code";
      expr = expression;
      inherit refId queryType;
    }
    // lib.optionalAttrs (legend != null) { legendFormat = legend; }
    // lib.optionalAttrs (maxLines != null) { inherit maxLines; }
    // lib.optionalAttrs (direction != null) { inherit direction; };
  mkLogsStat =
    {
      id,
      title,
      description,
      expression,
      links,
      x,
      y,
      w ? 6,
      h ? 4,
      unit ? "short",
      decimals ? 0,
      thresholds ? neutralThresholds,
    }:
    {
      inherit
        id
        title
        description
        ;
      type = "stat";
      datasource = logsDatasource;
      gridPos = {
        inherit
          h
          w
          x
          y
          ;
      };
      fieldConfig = {
        defaults = {
          inherit
            decimals
            unit
            thresholds
            ;
          links = links ++ [
            (mkExploreLink logsDatasource [
              {
                expr = expression;
                queryType = "stats";
                refId = "A";
              }
            ])
          ];
        };
        overrides = [ ];
      };
      options = {
        colorMode = "value";
        graphMode = "none";
        justifyMode = "auto";
        orientation = "auto";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        textMode = "auto";
        wideLayout = true;
      };
      targets = [ (mkLogsTarget { inherit expression; }) ];
    };
  mkLogsBarGauge =
    {
      id,
      title,
      description,
      expression,
      legend,
      x,
      y,
      w,
      h,
      unit ? "short",
      links ? [ ],
    }:
    {
      inherit
        id
        title
        description
        ;
      type = "bargauge";
      datasource = logsDatasource;
      gridPos = {
        inherit
          h
          w
          x
          y
          ;
      };
      fieldConfig = {
        defaults = {
          inherit unit;
          links = links ++ [
            (mkExploreLink logsDatasource [
              {
                expr = expression;
                queryType = "stats";
                refId = "A";
              }
            ])
          ];
          min = 0;
          thresholds = neutralThresholds;
        };
        overrides = [ ];
      };
      options = {
        displayMode = "gradient";
        maxVizHeight = 300;
        minVizHeight = 18;
        minVizWidth = 8;
        namePlacement = "left";
        orientation = "horizontal";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        showUnfilled = true;
        sizing = "auto";
        valueMode = "color";
      };
      targets = [
        (mkLogsTarget {
          inherit expression legend;
        })
      ];
    };
  mkLogsPanel =
    {
      id,
      title,
      description,
      expression,
      x,
      y,
      w,
      h,
      maxLines ? 500,
    }:
    {
      inherit
        id
        title
        description
        ;
      type = "logs";
      datasource = logsDatasource;
      gridPos = {
        inherit
          h
          w
          x
          y
          ;
      };
      links = lib.optionals (!lib.hasInfix "\${host:json}" expression) [
        (mkExploreLink logsDatasource [
          {
            expr = expression;
            queryType = "instant";
            refId = "A";
          }
        ])
      ];
      options = {
        dedupStrategy = "none";
        enableLogDetails = true;
        prettifyLogMessage = false;
        showCommonLabels = true;
        showLabels = true;
        showTime = true;
        sortOrder = "Descending";
        wrapLogMessage = true;
      };
      targets = [
        (mkLogsTarget {
          inherit expression maxLines;
          queryType = "instant";
          direction = "desc";
        })
      ];
    };
  journalVariables =
    map
      ({ name, label }: {
        current = {
          text = ".*";
          value = ".*";
        };
        hide = 0;
        inherit name label;
        query = ".*";
        options = [ ];
        skipUrlSync = false;
        type = "textbox";
      })
      [
        {
          name = "host";
          label = "Host (regex)";
        }
        {
          name = "manager";
          label = "Manager (system or username, regex)";
        }
        {
          name = "unit";
          label = "Unit (regex)";
        }
      ];
  metricsDatasourceVariable = {
    current = { };
    hide = 2;
    includeAll = false;
    multi = false;
    name = "datasource";
    options = [ ];
    query = "prometheus";
    refresh = 1;
    regex = "VictoriaMetrics";
    skipUrlSync = false;
    type = "datasource";
  };
  selectedJournal = ''
    {host=~''${host:json}}
    (manager:~''${manager:json} OR manager:"")
    (unit:~''${unit:json} OR _SYSTEMD_USER_UNIT:~''${unit:json} OR USER_UNIT:~''${unit:json} OR UNIT:~''${unit:json})
  '';
  failureJournal = ''${selectedJournal} _msg:~"(?i)(fail|error|fatal|panic|timed? out|timeout|uncorrectable|unable to|could not|cannot|permission denied|no space left|exit.code|status=[1-9])"'';
  serviceFailuresDashboard = pkgs.writeText "service-failures.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "Current failed units and their journal evidence. Filter by host, manager, and unit; historical messages do not imply that a unit is still failed.";
      editable = false;
      id = null;
      links = fleetDashboardLinks;
      panels = [
        (mkTable {
          id = 1;
          title = "Currently Failed Units";
          description = "Current metric state, independent of the journal time range. Click a unit to filter the messages below. If the cause is missing, widen the time range and check the full journal.";
          expression = failedUnitsExpression;
          x = 0;
          y = 0;
          w = 24;
          h = 7;
          fields = {
            host = 0;
            manager = 1;
            name = 2;
          };
          renamedFields = {
            host = "Host";
            manager = "Manager";
            name = "Unit";
          };
          overrides = [
            (mkFieldLinks "Unit" [
              (mkDashboardLink {
                uid = serviceFailuresUid;
                title = "Show this unit's failure messages";
                host = "\${__data.fields[\"Host\"]:percentencode}";
                manager = "\${__data.fields[\"Manager\"]:percentencode}";
                unit = "\${__data.fields[\"Unit\"]:percentencode}";
              })
            ])
          ];
          transformations = [
            {
              id = "filterByValue";
              options = {
                type = "include";
                match = "all";
                filters =
                  map
                    ({ field, variable }: {
                      fieldName = field;
                      config = {
                        id = "regex";
                        options.value = "^\${${variable}:raw}$";
                      };
                    })
                    [
                      {
                        field = "Host";
                        variable = "host";
                      }
                      {
                        field = "Manager";
                        variable = "manager";
                      }
                      {
                        field = "Unit";
                        variable = "unit";
                      }
                    ];
              };
            }
          ];
        })
        (mkLogsPanel {
          id = 2;
          title = "Failure Messages";
          description = "Error-like journal messages for the selected host, manager, and unit. Includes application errors such as DNS failures and scrub checksum errors. This text filter is a shortcut; the full journal below includes messages it does not match.";
          expression = failureJournal;
          x = 0;
          y = 7;
          w = 24;
          h = 12;
        })
        (mkLogsPanel {
          id = 3;
          title = "Full Unit Journal";
          description = "All collected journal messages for the selection, newest first. Expand a line for invocation IDs, exit results, and original journal fields. Messages require successful log shipping and must fall within the selected time range.";
          expression = selectedJournal;
          x = 0;
          y = 19;
          w = 24;
          h = 14;
        })
      ];
      refresh = "30s";
      schemaVersion = 42;
      tags = [
        "fleet"
        "systemd"
        "logs"
      ];
      templating.list = [ metricsDatasourceVariable ] ++ journalVariables;
      time = {
        from = "now-30d";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      title = "Service Failures";
      uid = serviceFailuresUid;
      version = 1;
    }
  );
  fleetLogsDashboard = pkgs.writeText "fleet-logs.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "Host and unit journal details behind fleet health, storage, deployment, and connectivity panels.";
      editable = false;
      id = null;
      links = fleetDashboardLinks;
      panels = [
        (mkLogsPanel {
          id = 1;
          title = "Errors And Failure Messages";
          description = "Error-like messages for the selection. Use the full journal for context and messages outside the text filter.";
          expression = failureJournal;
          x = 0;
          y = 0;
          w = 24;
          h = 12;
        })
        (mkLogsPanel {
          id = 2;
          title = "Full Journal";
          description = "Collected journal messages for the selected host, manager, and unit. Expand a line for original fields. Change the regex filters or widen the time range if necessary.";
          expression = selectedJournal;
          x = 0;
          y = 12;
          w = 24;
          h = 16;
        })
      ];
      refresh = "30s";
      schemaVersion = 42;
      tags = [
        "fleet"
        "logs"
      ];
      templating.list = journalVariables;
      time = {
        from = "now-24h";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      title = "Fleet Logs";
      uid = fleetLogsUid;
      version = 1;
    }
  );
  sshAccessDashboard = pkgs.writeText "ssh-access.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "SSH participants and outcomes across the fleet. Counts are log events in the selected time range, not unique people or interactive sessions.";
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = fleetDashboardLinks;
      liveNow = false;
      panels = [
        (mkRow {
          id = 1;
          title = "Security Posture";
          y = 0;
        })
        (mkLogsStat {
          id = 2;
          title = "Accepted authentications";
          description = "Successful OpenSSH authentication events. Click the value for the source, account, method, and key of each one.";
          expression = "${sshAccepted} | stats count() as logins";
          links = [
            (mkPanelLink {
              uid = sshAccessUid;
              panel = sshAcceptedPanel;
              title = "Show the matching events";
            })
          ];
          x = 0;
          y = 1;
        })
        (mkLogsStat {
          id = 3;
          title = "Accepted via internet";
          description = "Successful authentications from outside private, loopback, link-local, and Tailscale CGNAT ranges. Any value warrants identity review; click the value for the events behind it.";
          expression = "${sshInternetAccepted} | stats count() as logins";
          links = [
            (mkPanelLink {
              uid = sshAccessUid;
              panel = sshInternetAcceptedPanel;
              title = "Show the matching events";
            })
          ];
          x = 6;
          y = 1;
          thresholds = warningThresholds;
        })
        (mkLogsStat {
          id = 4;
          title = "Internet connections";
          description = "TCP connections to fleet SSH endpoints from public source addresses; this is exposure volume, not successful authentication. Click the value for the individual attempts.";
          expression = "${sshInternetConnections} | stats count() as connections";
          links = [
            (mkPanelLink {
              uid = sshAccessUid;
              panel = sshConnectionsPanel;
              title = "Show the matching events";
            })
          ];
          x = 12;
          y = 1;
        })
        (mkLogsStat {
          id = 5;
          title = "Credential rejections";
          description = "Failed credentials, invalid users, and maximum-attempt events. A connection can produce more than one rejection event. Click the value for the raw messages.";
          expression = "${sshCredentialFailures} | stats count() as rejections";
          links = [
            (mkPanelLink {
              uid = sshAccessUid;
              panel = sshRejectionsPanel;
              title = "Show the matching events";
            })
          ];
          x = 18;
          y = 1;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "green";
                value = null;
              }
              {
                color = "orange";
                value = 1;
              }
            ];
          };
        })

        (mkRow {
          id = 6;
          title = "Activity Over Time";
          y = 5;
        })
        {
          id = 7;
          title = "SSH activity by destination host";
          description = "Public connection volume, successful authentications, and credential-rejection events over the selected range.";
          type = "timeseries";
          datasource = logsDatasource;
          gridPos = {
            h = 8;
            w = 24;
            x = 0;
            y = 6;
          };
          fieldConfig = {
            defaults = {
              min = 0;
              unit = "short";
              color.mode = "palette-classic";
              custom = {
                axisCenteredZero = false;
                axisColorMode = "text";
                axisLabel = "Events";
                axisPlacement = "auto";
                drawStyle = "line";
                fillOpacity = 16;
                gradientMode = "none";
                lineInterpolation = "smooth";
                lineWidth = 2;
                pointSize = 4;
                scaleDistribution.type = "linear";
                showPoints = "never";
                spanNulls = false;
                stacking = {
                  group = "A";
                  mode = "none";
                };
                thresholdsStyle.mode = "off";
              };
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "green";
                    value = null;
                  }
                ];
              };
            };
            overrides = [ ];
          };
          options = {
            legend = {
              calcs = [ "lastNotNull" ];
              displayMode = "table";
              placement = "bottom";
              showLegend = true;
            };
            tooltip = {
              hideZeros = false;
              mode = "multi";
              sort = "desc";
            };
          };
          targets = [
            (mkLogsTarget {
              expression = "${sshInternetConnections} | stats by (host) count() as connections";
              refId = "A";
              queryType = "statsRange";
              legend = "Internet connections: {{host}}";
            })
            (mkLogsTarget {
              expression = "${sshAccepted} | stats by (host) count() as logins";
              refId = "B";
              queryType = "statsRange";
              legend = "Accepted: {{host}}";
            })
            (mkLogsTarget {
              expression = "${sshCredentialFailures} | stats by (host) count() as rejections";
              refId = "C";
              queryType = "statsRange";
              legend = "Rejected: {{host}}";
            })
          ];
        }

        (mkRow {
          id = 8;
          title = "Event Detail";
          y = 14;
        })
        (mkLogsPanel {
          id = sshAcceptedPanel;
          title = "Accepted authentication events";
          description = "Successful source -> destination identity events. Expand a line for the original journal fields.";
          expression = ''${sshAcceptedParsed} | format "info" as level | format "<source_ip> -> <host> user=<user> method=<method> key=<key_type> <fingerprint>"'';
          x = 0;
          y = 15;
          w = 12;
          h = 14;
          maxLines = 500;
        })
        (mkLogsPanel {
          id = sshInternetAcceptedPanel;
          title = "Accepted via internet events";
          description = "The subset of accepted authentications whose source address is outside private, loopback, link-local, and Tailscale CGNAT ranges. Every line here is a successful login from the public internet.";
          expression = ''${sshInternetAccepted} | format "error" as level | format "<source_ip> -> <host> user=<user> method=<method> key=<key_type> <fingerprint>"'';
          x = 12;
          y = 15;
          w = 12;
          h = 14;
          maxLines = 500;
        })
        (mkLogsPanel {
          id = sshConnectionsPanel;
          title = "SSH connection attempts";
          description = "Every source socket -> destination inventory host and local SSH endpoint, whether or not authentication was attempted.";
          expression = ''${sshConnections} | format "info" as level | format "<source_ip>:<source_port> -> <host> (<destination_ip>:<destination_port>)"'';
          x = 0;
          y = 29;
          w = 12;
          h = 14;
          maxLines = 500;
        })
        (mkLogsPanel {
          id = sshRejectionsPanel;
          title = "Credential rejection events";
          description = "Raw sshd messages behind the rejection count. The message shapes differ between failed credentials, invalid users, and maximum-attempt events, so the original text is shown instead of a parsed summary.";
          expression = ''${sshCredentialFailures} | format "warn" as level'';
          x = 12;
          y = 29;
          w = 12;
          h = 14;
          maxLines = 500;
        })

        (mkRow {
          id = 11;
          title = "Investigation Breakdowns";
          y = 43;
        })
        (mkLogsBarGauge {
          id = 12;
          title = "Top internet sources";
          description = "Public source addresses ranked by TCP connections, with the destination inventory host and local endpoint in each label.";
          expression = "${sshInternetConnections} | stats by (source_ip,host,destination_ip,destination_port) count() as connections | sort by (connections desc) limit 12";
          legend = "{{source_ip}} -> {{host}} ({{destination_ip}}:{{destination_port}})";
          x = 0;
          y = 44;
          w = 12;
          h = 10;
        })
        (mkLogsBarGauge {
          id = 13;
          title = "Targeted accounts";
          description = "Usernames observed in invalid-user and pre-authentication messages, ranked by event count. This is a narrower filter than Credential rejections and will not reconcile with it.";
          expression = "${sshTargetedAccounts} | stats by (user,source_ip,host) count() as events | sort by (events desc) limit 12";
          legend = "{{user}} <= {{source_ip}} -> {{host}}";
          x = 12;
          y = 44;
          w = 12;
          h = 10;
        })
      ];
      refresh = "30s";
      schemaVersion = 42;
      tags = [
        "fleet"
        "security"
        "ssh"
      ];
      templating.list = [ ];
      time = {
        from = "now-24h";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      title = "SSH Access";
      uid = sshAccessUid;
      version = 4;
      weekStart = "";
    }
  );
  lanActivityDashboard = pkgs.writeText "lan-activity.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "DNS activity, DHCP leases, and router events observed at the LAN gateway.";
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = fleetDashboardLinks;
      liveNow = false;
      panels = [
        (mkLogsBarGauge {
          id = 1;
          title = "Top DNS clients";
          description = "Clients ranked by DNS queries in the selected time range.";
          expression = "event_kind:dns_query dns.client:* | stats by (dns.client) count() as queries | sort by (queries desc) limit 15";
          legend = "{{dns.client}}";
          x = 0;
          y = 0;
          w = 12;
          h = 10;
        })
        (mkLogsBarGauge {
          id = 2;
          title = "Top queried names";
          description = "DNS names ranked by query count in the selected time range.";
          expression = "event_kind:dns_query dns.name:* | stats by (dns.name) count() as queries | sort by (queries desc) limit 15";
          legend = "{{dns.name}}";
          x = 12;
          y = 0;
          w = 12;
          h = 10;
        })
        (mkLogsPanel {
          id = 3;
          title = "DHCP leases";
          description = "Recent DHCP acknowledgements with client address, MAC, and hostname.";
          expression = "event_kind:dhcp_lease";
          x = 0;
          y = 10;
          w = 12;
          h = 12;
        })
        (mkLogsPanel {
          id = 4;
          title = "Router events";
          description = "Raw router-0 syslog events, including unparsed DNS and DHCP messages.";
          expression = ''{host="router-0"}'';
          x = 12;
          y = 10;
          w = 12;
          h = 12;
        })
      ];
      refresh = "30s";
      schemaVersion = 42;
      tags = [
        "dns"
        "fleet"
        "lan"
        "security"
      ];
      templating.list = [ ];
      time = {
        from = "now-24h";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      title = "LAN Activity";
      uid = "lan-activity";
      version = 1;
      weekStart = "";
    }
  );
  networkFlowsDashboard = pkgs.writeText "network-flows.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "Sampling-adjusted IPFIX flow volume and endpoints observed by fleet flow exporters.";
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = fleetDashboardLinks;
      liveNow = false;
      panels = [
        (mkLogsStat {
          id = 1;
          title = "Estimated bytes";
          description = "Sampling-adjusted bytes in the time range. Click for the top sources.";
          expression = "event_kind:network_flow | stats sum(flow.estimated_bytes) as bytes";
          links = [
            (mkPanelLink {
              uid = networkFlowsUid;
              panel = flowsTopSourcesPanel;
              title = "Show the top sources";
            })
          ];
          x = 0;
          y = 0;
          w = 12;
          h = 5;
          unit = "bytes";
          decimals = null;
        })
        (mkLogsStat {
          id = 2;
          title = "Flow records";
          description = "Decoded IPFIX records in the time range. Click for the raw records.";
          expression = "event_kind:network_flow | stats count() as flows";
          links = [
            (mkPanelLink {
              uid = networkFlowsUid;
              panel = flowsRawPanel;
              title = "Show the raw records";
            })
          ];
          x = 12;
          y = 0;
          w = 12;
          h = 5;
          decimals = null;
        })
        (mkLogsBarGauge {
          id = flowsTopSourcesPanel;
          title = "Top source addresses";
          description = "Sources ranked by sampling-adjusted bytes in observed flow records.";
          expression = "event_kind:network_flow flow.src_addr:* | stats by (flow.src_addr) sum(flow.estimated_bytes) as bytes | sort by (bytes desc) limit 12";
          legend = "{{flow.src_addr}}";
          x = 0;
          y = 5;
          w = 12;
          h = 10;
          unit = "bytes";
        })
        (mkLogsBarGauge {
          id = 4;
          title = "Top destination addresses";
          description = "Destinations ranked by sampling-adjusted bytes in observed flow records.";
          expression = "event_kind:network_flow flow.dst_addr:* | stats by (flow.dst_addr) sum(flow.estimated_bytes) as bytes | sort by (bytes desc) limit 12";
          legend = "{{flow.dst_addr}}";
          x = 12;
          y = 5;
          w = 12;
          h = 10;
          unit = "bytes";
        })
        {
          id = flowsRawPanel;
          title = "Raw flow records";
          description = "Decoded GoFlow2 records; expand a row to inspect all IPFIX fields.";
          type = "logs";
          datasource = logsDatasource;
          gridPos = {
            h = 12;
            w = 24;
            x = 0;
            y = 15;
          };
          options = {
            dedupStrategy = "none";
            enableLogDetails = true;
            prettifyLogMessage = true;
            showCommonLabels = false;
            showLabels = false;
            showTime = true;
            sortOrder = "Descending";
            wrapLogMessage = false;
          };
          targets = [
            {
              datasource = logsDatasource;
              direction = "desc";
              editorMode = "code";
              expr = "event_kind:network_flow";
              maxLines = 500;
              queryType = "instant";
              refId = "A";
            }
          ];
        }
      ];
      refresh = "30s";
      schemaVersion = 42;
      tags = [
        "fleet"
        "network"
        "security"
        "ipfix"
      ];
      templating.list = [ ];
      time = {
        from = "now-6h";
        to = "now";
      };
      timepicker = { };
      timezone = "browser";
      title = "Network Flows";
      uid = networkFlowsUid;
      version = 2;
      weekStart = "";
    }
  );
  dashboards = pkgs.linkFarm "grafana-fleet-dashboards" [
    {
      name = "service-failures.json";
      path = serviceFailuresDashboard;
    }
    {
      name = "fleet-logs.json";
      path = fleetLogsDashboard;
    }
    {
      name = "fleet-overview.json";
      path = dashboard;
    }
    {
      name = "alerts-overview.json";
      path = alertsDashboard;
    }
    {
      name = "ssh-access.json";
      path = sshAccessDashboard;
    }
    {
      name = "network-flows.json";
      path = networkFlowsDashboard;
    }
    {
      name = "lan-activity.json";
      path = lanActivityDashboard;
    }
  ];
in
{
  services.grafana = {
    declarativePlugins = [ pkgs.grafanaPlugins.victoriametrics-logs-datasource ];

    settings = {
      analytics = {
        check_for_updates = false;
        check_for_plugin_updates = false;
        feedback_links_enabled = false;
      };
      dashboards.default_home_dashboard_path = toString dashboard;
      help.enabled = false;
      news.news_feed_enabled = false;
      plugins.plugin_admin_enabled = false;
      public_dashboards.enabled = false;
      snapshots.enabled = false;
      unified_alerting.enabled = false;
    };

    provision.datasources.settings.datasources = [
      {
        name = "VictoriaLogs";
        uid = "victorialogs";
        type = "victoriametrics-logs-datasource";
        access = "proxy";
        url = "http://127.0.0.1:${toString config.services.cluster-victorialogs.listenPort}";
        isDefault = false;
        editable = false;
      }
    ];

    provision.dashboards.settings = {
      apiVersion = 1;
      providers = [
        {
          name = "fleet";
          orgId = 1;
          folder = "Fleet";
          type = "file";
          disableDeletion = true;
          editable = false;
          options.path = dashboards;
        }
      ];
    };
  };

  systemd = {
    tmpfiles.rules = [
      "L+ ${metricsDirectory}/fleet-monitoring-policy.prom - - - - ${monitoringPolicyMetrics}"
      "L+ ${metricsDirectory}/fleet-expected-tags.prom - - - - ${expectedTagMetrics}"
    ];

    services = {
      dotfiles-main-revision-metrics = {
        description = "Export the current dotfiles main revision";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe mainRevisionCollector;
        };
      };

      fleet-tailnet-metrics = {
        description = "Export Headscale node state for fleet monitoring";
        after = [ "headscale.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecCondition = "${config.systemd.package}/bin/systemctl is-active --quiet headscale.service";
          ExecStart = lib.getExe tailnetMetricsCollector;
          User = "root";
          Group = "root";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ metricsDirectory ];
          UMask = "0022";
        };
      };
    };

    timers = {
      dotfiles-main-revision-metrics = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2m";
          OnUnitActiveSec = "15m";
          Unit = "dotfiles-main-revision-metrics.service";
        };
      };

      fleet-tailnet-metrics = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "30s";
          Unit = "fleet-tailnet-metrics.service";
        };
      };
    };
  };
}
