{ lib, pkgs, ... }:
let
  datasource = {
    type = "prometheus";
    uid = "\${datasource}";
  };
  metricsDirectory = "/var/lib/prometheus-node-exporter-textfiles";
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
          text = "UNREACHABLE";
        };
        "1" = {
          color = "green";
          index = 1;
          text = "UP";
        };
      };
    }
    {
      type = "special";
      options = {
        match = "null";
        result = {
          color = "gray";
          index = 2;
          text = "N/A";
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
          color = "green";
          index = 1;
          text = "HEALTHY";
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
        w = 4;
        inherit x y;
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
      min ? null,
      max ? null,
      thresholds ? percentThresholds,
      mappings ? [ ],
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
            min
            max
            thresholds
            mappings
            ;
        };
        overrides = [ ];
      };
      options = {
        displayMode = "gradient";
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
          expression = ''min(up{job=~"fleet-(node|smartctl)"})'';
          x = 0;
          y = 1;
          min = 0;
          max = 1;
          thresholds = healthyThresholds;
          mappings = healthMappings;
          description = "All configured node and SMART exporters are reachable.";
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
          title = "Configured Monitoring Targets";
          description = "Every exporter VictoriaMetrics is configured to scrape. Best-effort targets may legitimately be offline; always-on targets should remain reachable.";
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
            overrides =
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
                  "Node"
                  "SMART"
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
              expression = withHost ''up{job=~"fleet-(node|smartctl)"}'';
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
                columnField = "exporter";
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
                    "node"
                    "smartctl"
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
                  "host\\exporter" = 0;
                  node = 1;
                  smartctl = 2;
                  Overall = 3;
                };
                renameByName = {
                  "host\\exporter" = "Host";
                  node = "Node";
                  smartctl = "SMART";
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
          id = 22;
          title = "Uptime";
          expression = withHost ''time() - node_boot_time_seconds{job="fleet-node"}'';
          legend = "{{host}}";
          x = 0;
          y = 41;
          w = 8;
          unit = "s";
          min = 0;
          thresholds = healthyThresholds;
        })
        (mkTimeSeries {
          id = 23;
          title = "System Load";
          x = 8;
          y = 41;
          w = 8;
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
        (mkBarGauge {
          id = 24;
          title = "Failed Systemd Units";
          expression = withHost ''sum by(instance) (node_systemd_unit_state{job="fleet-node",state="failed"})'';
          legend = "{{host}}";
          x = 16;
          y = 41;
          w = 8;
          min = 0;
          thresholds = warningThresholds;
          mappings = clearMappings;
        })

        (mkRow {
          id = 25;
          title = "Configuration Source";
          y = 49;
        })
        (mkTable {
          id = 26;
          title = "Configuration Freshness";
          description = "Compares each active NixOS source with the current dotfiles main branch. Path and dirty-tree builds are intentionally reported as local.";
          expression = configurationFreshnessExpression;
          x = 0;
          y = 50;
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
      version = 6;
      weekStart = "";
    }
  );
  dashboards = pkgs.linkFarm "grafana-fleet-dashboards" [
    {
      name = "fleet-overview.json";
      path = dashboard;
    }
  ];
in
{
  services.grafana = {
    settings = {
      analytics = {
        check_for_updates = false;
        check_for_plugin_updates = false;
        feedback_links_enabled = false;
      };
      dashboards.default_home_dashboard_path = toString dashboard;
      help.enabled = false;
      news.news_feed_enabled = false;
    };

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
    services.dotfiles-main-revision-metrics = {
      description = "Export the current dotfiles main revision";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe mainRevisionCollector;
      };
    };

    timers.dotfiles-main-revision-metrics = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = "15m";
        Unit = "dotfiles-main-revision-metrics.service";
      };
    };
  };
}
