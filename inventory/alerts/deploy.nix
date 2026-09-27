{
  groups = [
    {
      name = "deploy";
      interval = "1m";
      rules = [
        {
          alert = "RebootRequired";
          expr = "max by (host) (fleet_nixos_reboot_required) == 1";
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.host }} needs a reboot to finish its upgrade";
            description = "The active generation on {{ $labels.host }} changes a boot component (kernel, initrd, kernel modules or kernel parameters). Nothing reboots automatically. Reboot the host when its work allows it.";
          };
        }

        {
          alert = "UpgradeFailed";
          expr = ''fleet_upgrade_state{state="failed"} == 1'';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.host }} failed to upgrade ({{ $labels.reason }})";
            description = "fleet-upgrade.service on {{ $labels.host }} failed with reason '{{ $labels.reason }}'. The host keeps its current generation. Read 'journalctl -u fleet-upgrade' on the host.";
          };
        }

        {
          alert = "UpgradeStalled";
          expr = ''(time() - fleet_upgrade_last_success_timestamp_seconds) > 3 * 86400 unless on(host) fleet_upgrade_state{state="held"} == 1'';
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.host }} has not run its planned generation for 3 days";
            description = "{{ $labels.host }} is not held, but it has not matched its planned generation for 3 days. It may be offline in every upgrade window, fail to build, or wait for a Slurm controller that does not upgrade. Read 'journalctl -u fleet-upgrade' on the host and the plan on the deploy controller.";
          };
        }

        {
          alert = "DeployBuildFailed";
          expr = ''fleet_deploy_host_info{state="build-failed"} == 1'';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "The deploy controller cannot build {{ $labels.host }}";
            description = "The deploy controller failed to build {{ $labels.host }} at {{ $labels.revision }}. The host keeps its current generation. Read 'journalctl -u fleet-deploy-controller' on the controller.";
          };
        }

        {
          alert = "RolloutBlocked";
          expr = ''fleet_deploy_wave_info{state=~"blocked|metrics-unreachable|no-canary"} == 1'';
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "Rollout wave {{ $labels.wave }} is stopped ({{ $labels.state }})";
            description = "Wave {{ $labels.wave }} stays on {{ $labels.revision }} and does not take {{ $labels.candidate }}. 'blocked': a trusted host of the previous wave that runs a newer revision has failed units, failed its upgrade, or went down. 'metrics-unreachable': the controller cannot query VictoriaMetrics. 'no-canary': the previous wave has no trusted host that is not held.";
          };
        }

        {
          alert = "DeployControllerStale";
          expr = "time() - fleet_deploy_last_success_timestamp_seconds > 3 * 3600";
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "The deploy controller has not completed a run for 3 hours";
            description = "No host receives new generations while the controller is stale. Read 'journalctl -u fleet-deploy-controller' on the controller.";
          };
        }
      ];
    }
  ];
}
