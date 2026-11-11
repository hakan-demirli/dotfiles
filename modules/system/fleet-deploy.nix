{
  config,
  cluster,
  inputs,
  ...
}:
{
  cluster.autoUpgrade = {
    enable = true;
    planUrl = "http://${cluster.deployController}.ts.${config.services.tailscale.loginServerHost}:5102/plan.json";
    flake = inputs.self.lib.forge.flake "dotfiles";
    onCalendar = "*-*-* 04..06:00/10:00 Europe/Zurich";
    pushKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFqSvHkzRXUNI6SrV93YA4feHMuc2Xj1kkSvJTdH3gvH fleet-deploy-push"
    ];
  };
}
