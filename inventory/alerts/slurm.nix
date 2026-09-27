{
  groups = [
    {
      name = "slurm";
      interval = "1m";
      rules = [
        {
          alert = "SlurmControllerDown";
          expr = ''max by (instance) (up{job=~"fleet-slurm-.+"}) == 0'';
          for = "5m";
          labels.severity = "critical";
          annotations = {
            summary = "slurmctld on {{ $labels.instance }} does not answer";
            description = "The Slurm metrics endpoint on {{ $labels.instance }} has not answered for 5 minutes, so slurmctld is down or unreachable. No job starts or finishes. Read 'journalctl -u slurmctld' on the controller.";
          };
        }

        {
          alert = "SlurmNodesDown";
          expr = "max by (partition) (slurm_partition_nodes_down) > 0";
          for = "15m";
          labels.severity = "critical";
          annotations = {
            summary = "{{ $value }} Slurm nodes are down in partition {{ $labels.partition }}";
            description = "slurmctld marks {{ $value }} nodes of partition {{ $labels.partition }} as down, so jobs cannot use them. Run 'sinfo -R' for the reason. When the hosts are up, check slurmd, munged and the tailnet ACL for ports 6817 and 6818.";
          };
        }

        {
          alert = "SlurmNodesDrained";
          expr = "max by (partition) (slurm_partition_nodes_drain) > 0";
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $value }} Slurm nodes are drained in partition {{ $labels.partition }}";
            description = "{{ $value }} nodes of partition {{ $labels.partition }} accept no new jobs. Slurm drains a node after a failure, for example a failed prolog, epilog or kill, or an admin drains it. Run 'sinfo -R' for the reason and 'scontrol update nodename=<node> state=resume' after the fix.";
          };
        }

        {
          alert = "SlurmJobsStuck";
          expr = "(max by (partition) (slurm_partition_jobs_pending) - max by (partition) (slurm_partition_jobs_hold)) > 0 and max by (partition) (slurm_partition_nodes_idle) > 0 and max by (partition) (slurm_partition_jobs_running) == 0";
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "Jobs wait in partition {{ $labels.partition }} while its nodes are idle";
            description = "Partition {{ $labels.partition }} has pending jobs that are not held, idle nodes and no running job for 30 minutes. The jobs may request resources that no idle node has, or the scheduler is stuck. Run 'squeue -t PD -o \"%i %r\"' for the reason of each job.";
          };
        }
      ];
    }
  ];
}
