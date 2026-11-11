{
  config,
  lib,
  cluster,
  inputs,
  ...
}:
let
  metricsHost = lib.head cluster.hostsByDeploymentRole.mgmt-observability;
  inherit (inputs.self.lib) forge;
in
{
  sops.secrets."fleet-deploy/push-ssh-key".owner = "fleet-deploy";

  services = {
    fleet-deploy-controller = {
      repository = forge.repository "dotfiles";
      branch = "main";
      flake = forge.flake "dotfiles";
      metricsUrl = "http://${metricsHost}.ts.${config.services.tailscale.loginServerHost}:8428";
      push.sshKeyFile = config.sops.secrets."fleet-deploy/push-ssh-key".path;
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
