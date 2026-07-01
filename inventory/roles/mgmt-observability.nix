{
  id = "mgmt-observability";
  description = "Central observability stack: VictoriaMetrics + Grafana, scrapes every host with monitoring.enabled = true";
  kind = "nixos";
  node_role = "mgmt";
  modules = [
    "system/base"
    "system/server-base"
    "system/impermanence"
    "system/ephemeral-root"
    "services/victoriametrics"
    "services/victorialogs"
    "services/grafana"
    "services/vmalert"
    "services/alertmanager"
  ];
}
