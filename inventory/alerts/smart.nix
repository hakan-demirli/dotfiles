{
  groups = [
    {
      name = "smart";
      interval = "60s";
      rules = [
        {
          alert = "SmartHealthFailing";
          expr = "smartctl_device_smart_status == 0";
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = "{{ $labels.instance }} SMART overall-health FAILED on {{ $labels.device }}";
            description = "The disk {{ $labels.device }} on {{ $labels.instance }} reports SMART overall-health as failing. Replace the drive.";
          };
        }

        {
          alert = "NvmeMediaErrors";
          expr = "increase(smartctl_device_media_errors[1h]) > 0";
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = "{{ $labels.instance }} NVMe media errors on {{ $labels.device }}";
            description = "NVMe media_errors counter increased on {{ $labels.device }} in the last hour. The drive is silently corrupting reads.";
          };
        }

        {
          alert = "NvmePercentageUsedHigh";
          expr = "smartctl_device_percentage_used > 90";
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.instance }} NVMe wearout past 90% on {{ $labels.device }}";
            description = "SSD lifetime-used indicator for {{ $labels.device }} on {{ $labels.instance }} is over 90%. Plan a replacement.";
          };
        }

        {
          alert = "DiskTemperatureHigh";
          expr = "smartctl_device_temperature > 75";
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.instance }} disk temp over 75C on {{ $labels.device }}";
            description = "Disk {{ $labels.device }} on {{ $labels.instance }} has been above 75C for 15m. Check airflow / heatsink.";
          };
        }
      ];
    }
  ];
}
