let
  inherit (import ./_templates.nix) host;
in
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
            summary = "slurmctld on ${host} is down";
            description = "No jobs start or finish. Check: journalctl -u slurmctld";
          };
        }

        {
          alert = "SlurmNodesDown";
          expr = "max by (partition) (slurm_partition_nodes_down) > 0";
          for = "15m";
          labels.severity = "critical";
          annotations = {
            summary = "Slurm nodes down in {{ $labels.partition }}: {{ $value }}";
            description = "Check: sinfo -R";
          };
        }

        {
          alert = "SlurmNodesDrained";
          expr = "max by (partition) (slurm_partition_nodes_drain) > 0";
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "Slurm nodes drained in {{ $labels.partition }}: {{ $value }}";
            description = "Check: sinfo -R. Resume: scontrol update nodename=NODE state=resume";
          };
        }

        {
          alert = "SlurmJobsStuck";
          expr = "(max by (partition) (slurm_partition_jobs_pending) - max by (partition) (slurm_partition_jobs_hold)) > 0 and max by (partition) (slurm_partition_nodes_idle) > 0 and max by (partition) (slurm_partition_jobs_running) == 0";
          for = "30m";
          labels.severity = "warning";
          annotations = {
            summary = "Slurm jobs stuck in {{ $labels.partition }}";
            description = "Jobs pend while nodes are idle. Check: squeue -t PD -o \"%i %r\"";
          };
        }
      ];
    }
  ];
}
