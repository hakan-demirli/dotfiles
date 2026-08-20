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

        sinks.victorialogs = {
          type = "http";
          inputs = [ "label" ];
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
      listenAddress = "100.64.0.1";
    };

    vmalert.instances.default.settings = {
      "remoteRead.url" = config.services.cluster-vmalert.datasourceUrl;
      "remoteWrite.url" = config.services.cluster-vmalert.datasourceUrl;
    };
  };

  systemd.services = {
    vector = {
      wants = [ "victorialogs.service" ];
      after = [ "victorialogs.service" ];
    };

    vmalert-default = {
      wants = [ "victoriametrics.service" ];
      after = [ "victoriametrics.service" ];
    };
  };
}
