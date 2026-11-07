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
  };
}
