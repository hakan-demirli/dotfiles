{
  groups = [
    {
      name = "btrfs";
      interval = "60s";
      rules = [
        {
          alert = "BtrfsError";
          expr = "increase(node_btrfs_device_errors_total[1h]) > 0";
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = "{{ $labels.instance }} btrfs {{ $labels.type }} error on {{ $labels.device }}";
            description = "{{ $value }} new {{ $labels.type }} errors in the last hour. data=single, so nothing is repairable.";
          };
        }
      ];
    }
  ];
}
