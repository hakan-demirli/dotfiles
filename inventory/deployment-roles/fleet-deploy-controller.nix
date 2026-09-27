{
  id = "fleet-deploy-controller";
  description = "Builds, gates and serves the deployments of the whole fleet";
  kind = "nixos";
  modules = [
    "infra:services/fleet-deploy-controller"
    "infra:services/harmonia"
    "self:deployment-roles/fleet-deploy-controller"
  ];
}
