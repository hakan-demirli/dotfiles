{
  id = "mgmt-observability";
  description = "Central observability stack: VictoriaMetrics + Grafana, scrapes every host with monitoring.enabled = true";
  kind = "nixos";
  modules = [
    "infra:system/base"
    "infra:system/server-base"
    "infra:system/impermanence"
    "infra:system/ephemeral-root"
    "infra:services/victoriametrics"
    "infra:services/victorialogs"
    "self:services/flow-collector"
    "self:services/flow-exporter"
    "infra:services/grafana"
    "self:services/grafana-fleet"
    "infra:services/vmalert"
    "infra:services/alertmanager"
    "self:deployment-roles/mgmt-observability"
  ];
}
