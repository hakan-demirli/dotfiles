let
  inherit (import ./_templates.nix) host;
in
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
            summary = "${host} btrfs {{ $labels.type }} errors on {{ $labels.device }}";
            description = "{{ humanize $value }} new errors in the last hour. The data has no redundancy. Back it up now.";
          };
        }
      ];
    }
  ];
}
