{ config, cluster, ... }:
{
  cluster.autoUpgrade = {
    enable = true;
    planUrl = "http://${cluster.deployController}.ts.${config.services.tailscale.loginServerHost}:5102/plan.json";
    flake = "github:hakan-demirli/dotfiles";
  };
}
