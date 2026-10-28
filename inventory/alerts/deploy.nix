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
            summary = "{{ $labels.host }} needs a reboot";
            description = "Kernel or boot settings changed. Reboot to apply.";
          };
        }

        {
          alert = "UpgradeFailed";
          expr = ''fleet_upgrade_state{state="failed"} == 1'';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.host }} upgrade failed ({{ $labels.reason }})";
            description = "Still on the previous generation. Check: journalctl -u fleet-upgrade";
          };
        }

        {
          alert = "HomeUpgradeFailed";
          expr = ''fleet_user_systemd_unit_failed{name="fleet-home-upgrade.service"} == 1'';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.host }} home upgrade failed";
            description = "{{ $labels.user }} is still on the previous Home Manager generation. Check: journalctl --user -u fleet-home-upgrade";
          };
        }

        {
          alert = "HomeBehindSystem";
          expr = ''
            fleet_home_manager_generation_info{revision_kind=~"git|unknown"}
            unless on(host, revision) fleet_nixos_system_info
          '';
          for = "24h";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.host }} home does not follow the system revision";
            description = "{{ $labels.user }} runs Home Manager revision {{ reReplaceAll \"^(.{12}).*$\" \"$1\" $labels.revision }}. Check: journalctl --user -u fleet-home-upgrade";
          };
        }

        {
          alert = "UpgradeStalled";
          expr = ''(time() - fleet_upgrade_last_success_timestamp_seconds) > 3 * 86400 unless on(host) fleet_upgrade_state{state="held"} == 1'';
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "{{ $labels.host }} has not upgraded for 3 days";
            description = "Check: journalctl -u fleet-upgrade";
          };
        }

        {
          alert = "DeployBuildFailed";
          expr = ''fleet_deploy_host_info{state="build-failed"} == 1'';
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "Build failed for {{ $labels.host }}";
            description = "Revision {{ reReplaceAll \"^(.{12}).*$\" \"$1\" $labels.revision }}. Check: journalctl -u fleet-deploy-controller";
          };
        }

        {
          alert = "RolloutBlocked";
          expr = ''fleet_deploy_wave_info{state=~"blocked|metrics-unreachable|no-canary"} == 1'';
          for = "1h";
          labels.severity = "warning";
          annotations = {
            summary = "Rollout wave {{ $labels.wave }} is blocked";
            description = "{{ if eq $labels.state \"blocked\" }}A host in the previous wave failed.{{ else if eq $labels.state \"metrics-unreachable\" }}The controller cannot query VictoriaMetrics.{{ else }}The previous wave has no usable canary host.{{ end }}";
          };
        }

        {
          alert = "DeployControllerStale";
          expr = "time() - fleet_deploy_last_success_timestamp_seconds > 3 * 3600";
          for = "15m";
          labels.severity = "warning";
          annotations = {
            summary = "Deploy controller stalled";
            description = "No run for 3 hours. Check: journalctl -u fleet-deploy-controller";
          };
        }
      ];
    }
  ];
}
