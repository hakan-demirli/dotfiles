let
  inherit (import ./_templates.nix) host;
  gib = "1073741824";
  perFilesystem = expression: "sum by (job, instance, uuid) (${expression})";
  unallocated = perFilesystem "node_btrfs_device_unused_bytes";
  deviceSize = perFilesystem "node_btrfs_device_size_bytes";
  devices = "count by (job, instance, uuid) (node_btrfs_device_unused_bytes)";
  metadataFree = perFilesystem ''node_btrfs_size_bytes{block_group_type="metadata"} - node_btrfs_used_bytes{block_group_type="metadata"}'';
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

        {
          alert = "BtrfsUnallocatedLow";
          expr = "${unallocated} < 10 * ${gib} and ${unallocated} / ${deviceSize} < 0.05";
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "${host} btrfs {{ $labels.uuid }} has {{ humanize1024 $value }}B unallocated";
            description = "Data block groups hold almost all device space and the kernel reclaim does not keep up. Find the mount point with 'findmnt -S UUID={{ $labels.uuid }}' and run 'btrfs balance start -dusage=25' on it.";
          };
        }

        {
          alert = "BtrfsMetadataStarved";
          expr = "${unallocated} + ${metadataFree} < ${gib} * (3 + ${devices})";
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = "${host} btrfs {{ $labels.uuid }} cannot grow its metadata";
            description = "Unallocated and free metadata space total {{ humanize1024 $value }}B. New files fail with 'No space left on device' while df still reports free space. Delete data, then run 'btrfs balance start -dusage=25' on the mount point.";
          };
        }
      ];
    }
  ];
}
