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
            summary = "VictoriaMetrics on-disk data projected to exceed VPS root FS within 7 days";
            description = "Based on the last 6 hours of growth, VictoriaMetrics will fill the VPS root filesystem in under 7 days. Reduce retention_period or add ingest filtering.";
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
            summary = "Over 50% of scrapes for {{ $labels.job }} failing for 30m";
            description = "VictoriaMetrics scrape job {{ $labels.job }} is failing more than half its attempts. Either the exporter is broken or a firewall/network changed.";
          };
        }

        {
          alert = "Watchdog";
          expr = "vector(1)";
          for = "0m";
          labels.severity = "none";
          annotations = {
            summary = "vmalert alive";
            description = "This alert should always fire. Its absence means the alerting pipeline is broken.";
          };
        }

        {
          alert = "NoAlertsFiringWhenExpected";
          expr = ''absent(ALERTS{alertname="Watchdog"})'';
          for = "5m";
          labels.severity = "warning";
          annotations = {
            summary = "Watchdog alert not firing";
            description = "The always-firing Watchdog alert is missing. vmalert is either not evaluating rules or cannot reach VictoriaMetrics.";
          };
        }
      ];
    }
  ];
}
