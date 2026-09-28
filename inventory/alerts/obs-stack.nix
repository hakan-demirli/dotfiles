{
  groups = [
    {
      name = "obs-stack";
      interval = "60s";
      rules = [
        {
          alert = "VictoriaMetricsDataGrowingFast";
          expr = ''
            predict_linear(vm_data_size_bytes[6h], 7 * 24 * 3600)
            > (
                node_filesystem_size_bytes{mountpoint="/",instance=~"vps-oracle-0.*"}
              )
          '';
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "VictoriaMetrics will fill the disk within 7 days";
            description = "Lower the retention or filter ingest.";
          };
        }

        {
          alert = "ScrapeFailingSustained";
          expr = ''
            (
              rate(vm_promscrape_scrapes_failed_total[15m])
              /
              (rate(vm_promscrape_scrapes_total[15m]) > 0)
            ) > 0.5
          '';
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "Scrapes failing for {{ $labels.job }}";
            description = "Over half of the scrapes fail.";
          };
        }

        {
          alert = "Watchdog";
          expr = "vector(1)";
          for = "0m";
          labels.severity = "none";
          annotations = {
            summary = "vmalert alive";
            description = "Always fires. If it stops, alerting is broken.";
          };
        }

        {
          alert = "NoAlertsFiringWhenExpected";
          expr = ''absent(ALERTS{alertname="Watchdog"})'';
          for = "5m";
          labels.severity = "warning";
          annotations = {
            summary = "Alerting is broken";
            description = "The Watchdog alert is missing. Check vmalert and VictoriaMetrics.";
          };
        }
      ];
    }
  ];
}
