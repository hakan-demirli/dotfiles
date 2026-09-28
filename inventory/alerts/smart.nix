let
  inherit (import ./_templates.nix) host;
in
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
            summary = "${host} disk {{ $labels.device }} is failing";
            description = "SMART health check failed. Replace the disk.";
          };
        }

        {
          alert = "NvmeMediaErrors";
          expr = "increase(smartctl_device_media_errors[1h]) > 0";
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = "${host} disk {{ $labels.device }} has media errors";
            description = "{{ humanize $value }} new errors in the last hour. Back up the data and replace the disk.";
          };
        }

        {
          alert = "NvmePercentageUsedHigh";
          expr = "smartctl_device_percentage_used > 90";
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "${host} disk {{ $labels.device }} is over 90% worn";
            description = "Plan a replacement.";
          };
        }

        {
          alert = "DiskTemperatureHigh";
          expr = "smartctl_device_temperature > 75";
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "${host} disk {{ $labels.device }} is hot";
            description = "{{ humanize $value }}°C for 15 minutes. Check the cooling.";
          };
        }
      ];
    }
  ];
}
