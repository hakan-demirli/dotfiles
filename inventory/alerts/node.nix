{
  groups = [
    {
      name = "node";
      interval = "30s";
      rules = [
        {
          alert = "HostDown";
          expr = ''up{job=~"fleet-node.*", always_on="true"} == 0'';
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = "{{ $labels.instance }} has been unreachable for 5m";
            description = "VictoriaMetrics could not scrape node_exporter on {{ $labels.instance }} (always-on host) for 5 minutes.";
          };
        }

        {
          alert = "HostStale";
          expr = ''
            (time() - max by (instance) (
              timestamp(up{job=~"fleet-node.*", always_on="false"})
            )) > 7 * 24 * 3600
          '';
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.instance }} not seen for over a week";
            description = "Sleep-eligible host {{ $labels.instance }} has not been reachable for more than 7 days. Either it is retired, dead, or off-fleet.";
          };
        }

        {
          alert = "DiskFillingFast";
          expr = ''
            (
              (node_filesystem_size_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs"}
               - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs"})
              / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs"}
            ) > 0.90
          '';
          for = "10m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.instance }} {{ $labels.mountpoint }} over 90% full";
            description = "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} is above 90% for 10m.";
          };
        }

        {
          alert = "DiskCritical";
          expr = ''
            (
              (node_filesystem_size_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs"}
               - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs"})
              / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs|devtmpfs"}
            ) > 0.97
          '';
          for = "2m";
          labels.severity = "critical";
          annotations = {
            summary = "{{ $labels.instance }} {{ $labels.mountpoint }} over 97% full";
            description = "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} is above 97%. Free space or the box will fall over.";
          };
        }

        {
          alert = "MemoryLow";
          expr = "(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.10";
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.instance }} MemAvailable under 10% for 15m";
            description = "Available memory on {{ $labels.instance }} is below 10% of total for 15 minutes. Something is leaking or the workload is heavier than provisioned.";
          };
        }

        {
          alert = "LoadHigh";
          expr = ''
            node_load15
            / on(instance) count without (cpu) (node_cpu_seconds_total{mode="idle"})
            > 2
          '';
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.instance }} load15 over 2x CPU count";
            description = "15-minute load average on {{ $labels.instance }} is more than 2x the CPU count for 30 minutes. Sustained overcommit.";
          };
        }
      ];
    }
  ];
}
