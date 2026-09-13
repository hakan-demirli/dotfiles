{
  config,
  host,
  ...
}:
{
  services = {
    vector = {
      enable = true;
      journaldAccess = true;
      settings = {
        sources.journald = {
          type = "journald";
          current_boot_only = true;
        };

        sources.router-syslog = {
          type = "syslog";
          address = "0.0.0.0:5514";
          mode = "tcp";
          max_length = 131072;
        };

        transforms.label = {
          type = "remap";
          inputs = [ "journald" ];
          source = ''
            .host = "${host.id}"
            .unit = del(._SYSTEMD_UNIT)
            if .unit == null { .unit = "unknown" }
            .priority = del(.PRIORITY)
            if .priority == null { .priority = "info" }

            if .unit == "goflow2.service" {
              parsed, err = parse_json(.message)
              if err == null && is_object(parsed) {
                sampling_rate = to_int(parsed.sampling_rate) ?? 1
                if sampling_rate < 1 { sampling_rate = 1 }
                parsed.estimated_bytes = (to_int(parsed.bytes) ?? 0) * sampling_rate
                parsed.estimated_packets = (to_int(parsed.packets) ?? 0) * sampling_rate
                .event_kind = "network_flow"
                .observer = .host
                .flow = parsed
              }
            }
          '';
        };

        transforms.router-label = {
          type = "remap";
          inputs = [ "router-syslog" ];
          source = ''
            .observer = "router-0"
            .host = "router-0"
            .unit = to_string(.appname) ?? "openwrt"
            .priority = to_string(.severity) ?? "info"

            message = to_string(.message) ?? ""
            dns, dns_err = parse_regex(message, r'^(?:[0-9]+ [^ ]+ )?query\[(?P<query_type>[^]]+)\] (?P<name>[^ ]+) from (?P<client>[^ ]+)$')
            if dns_err == null {
              .event_kind = "dns_query"
              .dns = dns
            }

            lease, lease_err = parse_regex(message, r'^DHCPACK\((?P<interface>[^)]+)\) (?P<address>[^ ]+) (?P<mac>[^ ]+)(?: (?P<hostname>[^ ]+))?$')
            if lease_err == null {
              .event_kind = "dhcp_lease"
              .lease = lease
            }
          '';
        };

        sinks.victorialogs = {
          type = "http";
          inputs = [
            "label"
            "router-label"
          ];
          uri = "http://127.0.0.1:${toString config.services.cluster-victorialogs.listenPort}/insert/jsonline?_stream_fields=host,unit&_msg_field=message&_time_field=timestamp";
          method = "post";
          encoding.codec = "json";
          framing.method = "newline_delimited";
          batch = {
            max_events = 200;
            timeout_secs = 5;
          };
          request = {
            timeout_secs = 10;
            retry_attempts = 5;
            retry_initial_backoff_secs = 1;
            retry_max_duration_secs = 60;
          };
        };
      };
    };

    cluster-flow-exporter = {
      enable = true;
      collectorAddress = "100.64.0.1";
    };

    cluster-flow-collector = {
      enable = true;
      listenAddress = "0.0.0.0";
    };

    vmalert.instances.default.settings = {
      "remoteRead.url" = config.services.cluster-vmalert.datasourceUrl;
      "remoteWrite.url" = config.services.cluster-vmalert.datasourceUrl;
    };
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [ 5514 ];
    allowedUDPPorts = [ config.services.cluster-flow-collector.netflowPort ];
  };

  systemd.services = {
    vector = {
      wants = [
        "tailscaled.service"
        "victorialogs.service"
      ];
      after = [
        "tailscaled.service"
        "victorialogs.service"
      ];
    };

    vmalert-default = {
      wants = [ "victoriametrics.service" ];
      after = [ "victoriametrics.service" ];
    };
  };
}
