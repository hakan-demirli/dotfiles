{
  config,
  lib,
  cluster,
  ...
}:
let
  metricsHost = lib.head cluster.hostsByDeploymentRole.mgmt-observability;
in
{
  services = {
    fleet-deploy-controller = {
      repository = "https://github.com/hakan-demirli/dotfiles.git";
      branch = "main";
      flake = "github:hakan-demirli/dotfiles";
      metricsUrl = "http://${metricsHost}.ts.${config.services.tailscale.loginServerHost}:8428";
    };

    cluster-harmonia = {
      firewallInterface = config.services.tailscale.interfaceName;
      signKey = {
        source = "sops";
        sopsKeyName = "fleet-deploy-cache-key";
      };
    };
  };
}
