{
  cluster,
  config,
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

      {
        printf '%s\n' '# HELP fleet_tailnet_node_status Headscale node state: 1=offline, 2=online.'
        printf '%s\n' '# TYPE fleet_tailnet_node_status gauge'
        headscale nodes list --output json | jq -r '
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
  healthMappings = [
    {
      type = "value";
      options = {
        "0" = {
          color = "red";
          index = 0;
          text = "DEGRADED";
        };
        "1" = {
          color = "green";
          index = 1;
          text = "HEALTHY";
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
          color = "orange";
          index = 1;
          text = "DOWN";
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
          color = "orange";
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
          text = "DEGRADED";
        };
        "1" = {
          color = "gray";
          index = 1;
          text = "N/A";
        };
        "2" = {
          color = "green";
          index = 2;
          text = "HEALTHY";
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
          color = "red";
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
  diskHealthExpression = ''
    label_join(
      label_replace(
        (
          label_replace(smartctl_device_smart_status{job="fleet-smartctl"}, "reading", "SMART", "__name__", ".*")
          or label_replace(smartctl_device_temperature{job="fleet-smartctl",temperature_type="current"}, "reading", "Temperature", "__name__", ".*")
          or label_replace(smartctl_device_percentage_used{job="fleet-smartctl"}, "reading", "Wear", "__name__", ".*")
          or label_replace(smartctl_device_available_spare{job="fleet-smartctl"}, "reading", "Spare", "__name__", ".*")
          or label_replace(smartctl_device_critical_warning{job="fleet-smartctl"}, "reading", "Critical warnings", "__name__", ".*")
          or label_replace(smartctl_device_media_errors{job="fleet-smartctl"}, "reading", "Media errors", "__name__", ".*")
          or label_replace(smartctl_device_power_on_seconds{job="fleet-smartctl"}, "reading", "Power-on time", "__name__", ".*")
        ),
        "host", "$1", "instance", "([^.:]+).*"
      ),
      "disk", " / ", "host", "device"
    )
  '';
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
        };
        overrides = [ ];
      };
      options = {
        inherit colorMode;
        graphMode = "area";
        justifyMode = "auto";
        orientation = "auto";
        reduceOptions = {
          calcs = [ "lastNotNull" ];
          fields = "";
          values = false;
        };
        showPercentChange = false;
        textMode = "auto";
        wideLayout = true;
      };
      targets = [
        (mkTarget {
          inherit expression;
          legend = "";
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
      overrides ? [ ],
      excludedFields ? {
        Time = true;
        Value = true;
        __name__ = true;
        always_on = true;
        closure = true;
        cluster = true;
        exporter = true;
        instance = true;
        job = true;
        revision = true;
      },
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
        h = 7;
        inherit w x y;
      };
      fieldConfig = {
        defaults = { };
        inherit overrides;
      };
      options = {
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
          id = "organize";
          options = {
            excludeByName = excludedFields;
            indexByName = fields;
            renameByName = renamedFields;
          };
        }
      ];
    };

  dashboard = pkgs.writeText "fleet-overview.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "Operational health, capacity, storage, disk health, and deployment state for the personal fleet.";
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = [ ];
      liveNow = false;
      panels = [
        (mkRow {
          id = 1;
          title = "Fleet At A Glance";
          y = 0;
        })
        (mkStat {
          id = 2;
          title = "Fleet status";
          expression = ''min(up{job=~"fleet-(node|smartctl)",always_on="true"})'';
          x = 0;
          y = 1;
          min = 0;
          max = 1;
          thresholds = healthyThresholds;
          mappings = healthMappings;
          description = "All always-on node and SMART exporters are reachable. Disabled and optional targets do not degrade this status.";
        })
        (mkStat {
          id = 3;
          title = "Highest CPU";
          expression = ''max((1 - avg by(instance) (rate(node_cpu_seconds_total{job="fleet-node",mode="idle"}[5m]))) * 100)'';
          x = 4;
          y = 1;
          unit = "percent";
          decimals = 1;
          min = 0;
          max = 100;
          description = "Busiest host over the last five minutes.";
        })
        (mkStat {
          id = 4;
          title = "Highest memory";
          expression = ''max((1 - node_memory_MemAvailable_bytes{job="fleet-node"} / node_memory_MemTotal_bytes{job="fleet-node"}) * 100)'';
          x = 8;
          y = 1;
          unit = "percent";
          decimals = 1;
          min = 0;
          max = 100;
          description = "Highest memory utilization across online hosts.";
        })
        (mkStat {
          id = 5;
          title = "Highest root usage";
          expression = ''max((1 - node_filesystem_avail_bytes{job="fleet-node",mountpoint="/"} / node_filesystem_size_bytes{job="fleet-node",mountpoint="/"}) * 100)'';
          x = 12;
          y = 1;
          unit = "percent";
          decimals = 1;
          min = 0;
          max = 100;
          description = "Most utilized root filesystem in the fleet.";
        })
        (mkStat {
          id = 6;
          title = "Disk health";
          expression = ''min(smartctl_device_smart_status{job="fleet-smartctl"})'';
          x = 16;
          y = 1;
          min = 0;
          max = 1;
          thresholds = healthyThresholds;
          mappings = healthMappings;
          description = "SMART status for physical disks that expose health data.";
        })
        (mkStat {
          id = 7;
          title = "Failed services";
          expression = ''sum(node_systemd_unit_state{job="fleet-node",state="failed"})'';
          x = 20;
          y = 1;
          thresholds = warningThresholds;
          mappings = clearMappings;
          description = "Total failed systemd units across online hosts.";
        })

        {
          id = 28;
          title = "Fleet Connectivity And Monitoring";
          description = "Tailnet reports Headscale node state; exporter columns report metric reachability. Disabled exporters are N/A, and optional failures do not degrade fleet health.";
          type = "table";
          inherit datasource;
          gridPos = {
            h = 8;
            w = 24;
            x = 0;
            y = 5;
          };
          fieldConfig = {
            defaults = { };
            overrides = [
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
          y = 13;
        })
        (mkTimeSeries {
          id = 9;
          title = "CPU Utilization";
          x = 0;
          y = 14;
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
          id = 10;
          title = "Memory Utilization";
          x = 8;
          y = 14;
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
          id = 11;
          title = "Root Filesystem Utilization";
          x = 16;
          y = 14;
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
          y = 22;
        })
        (mkTimeSeries {
          id = 13;
          title = "Network Throughput";
          x = 0;
          y = 23;
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
          y = 23;
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
          y = 31;
        })
        (mkBarGauge {
          id = 16;
          title = "Filesystem Usage";
          expression = withHost ''100 * (1 - node_filesystem_avail_bytes{job="fleet-node",mountpoint=~"/|/boot|/home"} / node_filesystem_size_bytes{job="fleet-node",mountpoint=~"/|/boot|/home"})'';
          legend = "{{host}}  {{mountpoint}}";
          x = 0;
          y = 32;
          w = 8;
          unit = "percent";
          min = 0;
          max = 100;
          description = "Usage for root, boot, and dedicated home filesystems.";
        })
        {
          id = 17;
          title = "Physical Disk Health";
          description = "One row per SMART-capable physical disk. Hosts without SMART access do not appear here.";
          type = "table";
          inherit datasource;
          gridPos = {
            h = 8;
            w = 16;
            x = 8;
            y = 32;
          };
          fieldConfig = {
            defaults = { };
            overrides = [
              {
                matcher = {
                  id = "byName";
                  options = "SMART";
                };
                properties = [
                  {
                    id = "mappings";
                    value = healthMappings ++ notAvailableMapping;
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
                  options = "Temperature";
                };
                properties = [
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
                  options = "Wear";
                };
                properties = [
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
                  options = "Spare";
                };
                properties = [
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
                  options = "Power-on time";
                };
                properties = [
                  {
                    id = "unit";
                    value = "s";
                  }
                  {
                    id = "mappings";
                    value = notAvailableMapping;
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
                      value = clearMappings ++ notAvailableMapping;
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
                })
                [
                  "Critical warnings"
                  "Media errors"
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
                  SMART = 1;
                  Temperature = 2;
                  Wear = 3;
                  Spare = 4;
                  "Critical warnings" = 5;
                  "Media errors" = 6;
                  "Power-on time" = 7;
                };
                renameByName."disk\\reading" = "Host / Device";
              };
            }
          ];
        }

        (mkRow {
          id = 21;
          title = "System State";
          y = 40;
        })
        (mkBarGauge {
          id = 29;
          title = "Availability";
          description = "Share of the selected time range in which the node exporter scrape succeeded. Restricted to always-on hosts because optional hosts are expected to be offline. A host absent from service discovery for part of the range is not counted as down.";
          expression = withHost ''avg_over_time(up{job="fleet-node",always_on="true"}[$__range]) * 100'';
          legend = "{{host}}";
          x = 0;
          y = 41;
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
          description = "Time since last boot. This is a duration, not an availability ratio; bar length compares hosts against the longest-running host. Use Availability for the reachability percentage.";
          expression = withHost ''time() - node_boot_time_seconds{job="fleet-node"}'';
          legend = "{{host}}";
          x = 8;
          y = 41;
          w = 8;
          unit = "s";
          min = 0;
          thresholds = uptimeThresholds;
          displayMode = "basic";
        })
        (mkBarGauge {
          id = 24;
          title = "Failed Systemd Units";
          description = "Units in the failed state per host.";
          expression = withHost ''sum by(instance) (node_systemd_unit_state{job="fleet-node",state="failed"})'';
          legend = "{{host}}";
          x = 16;
          y = 41;
          w = 8;
          min = 0;
          thresholds = warningThresholds;
          mappings = clearMappings;
          displayMode = "basic";
        })
        (mkTimeSeries {
          id = 23;
          title = "System Load";
          x = 0;
          y = 49;
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

        (mkRow {
          id = 25;
          title = "Configuration Source";
          y = 57;
        })
        (mkTable {
          id = 26;
          title = "Configuration Freshness";
          description = "Compares each active NixOS source with the current dotfiles main branch. Path and dirty-tree builds are intentionally reported as local.";
          expression = configurationFreshnessExpression;
          x = 0;
          y = 58;
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
          excludedFields = {
            Time = true;
            __name__ = true;
            closure = true;
            generation = true;
            instance = true;
            job = true;
            revision = true;
            revision_kind = true;
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
      uid = "fleet-revisions";
      version = 8;
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
      links = [
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
          url = "http://100.64.0.1:${toString config.services.cluster-alertmanager.listenPort}/";
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
          url = "http://100.64.0.1:${toString config.services.cluster-vmalert.listenPort}/";
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
          description = "Firing critical alerts, excluding the Watchdog heartbeat.";
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
          description = "Firing warning alerts, excluding the Watchdog heartbeat.";
        })
        (mkStat {
          id = 3;
          title = "Pending";
          expression = ''sum(ALERTS{alertstate="pending",severity!="none"}) or vector(0)'';
          x = 12;
          y = 0;
          w = 6;
          min = 0;
          thresholds = alertWarningThresholds;
          description = "Alerts whose conditions are true but whose hold duration has not elapsed.";
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
          mappings = healthMappings;
          description = "The Watchdog proves vmalert is evaluating rules and persisting alert state.";
        })
        (mkTable {
          id = 5;
          title = "Active alerts";
          description = "Actionable pending and firing alerts. Open Alertmanager above for annotations, routing, and silences.";
          expression = ''ALERTS{alertstate=~"pending|firing",severity!="none"}'';
          x = 0;
          y = 4;
          w = 24;
          fields = {
            severity = 0;
            alertname = 1;
            instance = 2;
            alertgroup = 3;
            alertstate = 4;
          };
          renamedFields = {
            severity = "Severity";
            alertname = "Alert";
            instance = "Instance";
            alertgroup = "Group";
            alertstate = "State";
          };
          excludedFields = {
            Time = true;
            Value = true;
            __name__ = true;
            always_on = true;
            cluster = true;
            exported_alertname = true;
            exporter = true;
            job = true;
          };
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
              ];
            }
          ];
        })
        (mkTimeSeries {
          id = 6;
          title = "Firing alerts by severity";
          description = "Historical count of actionable firing alerts from vmalert's persisted state.";
          targets = [
            (mkTarget {
              expression = ''sum by (severity) (ALERTS{alertstate="firing",severity!="none"})'';
              legend = "{{severity}}";
              refId = "A";
            })
          ];
          x = 0;
          y = 11;
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
      detailPanel,
      x,
      y,
      thresholds ? {
        mode = "absolute";
        steps = [
          {
            color = "blue";
            value = null;
          }
        ];
      },
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
        h = 4;
        w = 6;
        inherit x y;
      };
      fieldConfig = {
        defaults = {
          decimals = 0;
          unit = "short";
          inherit thresholds;
          links = [
            {
              title = "Show the matching events";
              url = "/d/${sshAccessUid}?viewPanel=${toString detailPanel}&\${__url_time_range}";
              targetBlank = false;
            }
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
          min = 0;
          thresholds = {
            mode = "absolute";
            steps = [
              {
                color = "blue";
                value = null;
              }
            ];
          };
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
  sshAccessDashboard = pkgs.writeText "ssh-access.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "SSH participants and outcomes across the fleet. Counts are log events in the selected time range, not unique people or interactive sessions.";
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = [ ];
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
          detailPanel = sshAcceptedPanel;
          x = 0;
          y = 1;
        })
        (mkLogsStat {
          id = 3;
          title = "Accepted via internet";
          description = "Successful authentications from outside private, loopback, link-local, and Tailscale CGNAT ranges. Any value warrants identity review; click the value for the events behind it.";
          expression = "${sshInternetAccepted} | stats count() as logins";
          detailPanel = sshInternetAcceptedPanel;
          x = 6;
          y = 1;
          thresholds = warningThresholds;
        })
        (mkLogsStat {
          id = 4;
          title = "Internet connections";
          description = "TCP connections to fleet SSH endpoints from public source addresses; this is exposure volume, not successful authentication. Click the value for the individual attempts.";
          expression = "${sshInternetConnections} | stats count() as connections";
          detailPanel = sshConnectionsPanel;
          x = 12;
          y = 1;
        })
        (mkLogsStat {
          id = 5;
          title = "Credential rejections";
          description = "Failed credentials, invalid users, and maximum-attempt events. A connection can produce more than one rejection event. Click the value for the raw messages.";
          expression = "${sshCredentialFailures} | stats count() as rejections";
          detailPanel = sshRejectionsPanel;
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
  networkFlowsDashboard = pkgs.writeText "network-flows.json" (
    builtins.toJSON {
      annotations.list = [ ];
      description = "Sampling-adjusted IPFIX flow volume and endpoints observed by fleet flow exporters.";
      editable = false;
      fiscalYearStartMonth = 0;
      graphTooltip = 1;
      id = null;
      links = [ ];
      liveNow = false;
      panels = [
        {
          id = 1;
          title = "Estimated bytes";
          description = "Total sampling-adjusted bytes represented by flow records in the selected time range.";
          type = "stat";
          datasource = logsDatasource;
          gridPos = {
            h = 5;
            w = 12;
            x = 0;
            y = 0;
          };
          fieldConfig = {
            defaults = {
              color.mode = "thresholds";
              unit = "bytes";
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "blue";
                    value = null;
                  }
                ];
              };
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
          targets = [
            {
              datasource = logsDatasource;
              editorMode = "code";
              expr = "event_kind:network_flow | stats sum(flow.estimated_bytes) as bytes";
              queryType = "stats";
              refId = "A";
            }
          ];
        }
        {
          id = 2;
          title = "Flow records";
          description = "Number of decoded IPFIX records in the selected time range.";
          type = "stat";
          datasource = logsDatasource;
          gridPos = {
            h = 5;
            w = 12;
            x = 12;
            y = 0;
          };
          fieldConfig = {
            defaults = {
              color.mode = "thresholds";
              thresholds = {
                mode = "absolute";
                steps = [
                  {
                    color = "blue";
                    value = null;
                  }
                ];
              };
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
          targets = [
            {
              datasource = logsDatasource;
              editorMode = "code";
              expr = "event_kind:network_flow | stats count() as flows";
              queryType = "stats";
              refId = "A";
            }
          ];
        }
        (mkLogsBarGauge {
          id = 3;
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
          id = 5;
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
      uid = "network-flows";
      version = 2;
      weekStart = "";
    }
  );
  dashboards = pkgs.linkFarm "grafana-fleet-dashboards" [
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
        requires = [ "headscale.service" ];
        after = [ "headscale.service" ];
        serviceConfig = {
          Type = "oneshot";
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
