let
  inherit (import ./_templates.nix) host;
in
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
            summary = "${host} is unreachable";
            description = "node_exporter does not answer. Check power and the tailnet.";
          };
        }

        {
          alert = "HostStale";
          expr = ''max_over_time(up{job=~"fleet-node.*", always_on="false"}[7d]) == 0'';
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "${host} offline for 7 days";
            description = "Optional host. Bring it online or retire it in the inventory.";
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
            summary = "${host} {{ $labels.mountpoint }} is over 90% full";
            description = "{{ $value | humanizePercentage }} used.";
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
            summary = "${host} {{ $labels.mountpoint }} is over 97% full";
            description = "{{ $value | humanizePercentage }} used. Free space now.";
          };
        }

        {
          alert = "MemoryLow";
          expr = "(node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.10";
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "${host} is low on memory";
            description = "{{ $value | humanizePercentage }} of memory available.";
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
            summary = "${host} is overloaded";
            description = "15-minute load is {{ printf \"%.1f\" $value }}× the CPU count.";
          };
        }
      ];
    }
  ];
}
