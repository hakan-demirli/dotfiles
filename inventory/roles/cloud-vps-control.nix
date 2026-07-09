{
  id = "cloud-vps-control";
  description = "Cloud VPS control plane";
  kind = "nixos";
  node_role = "controller";
  modules = [
    "system/base"
    "system/server-base"
    "system/impermanence"
    "system/ephemeral-root"
    "system/nix-settings"
    "services/headscale"
    "services/tailscale"
    "services/ntfy"
    "services/reverse-ssh-server"
    "services/harmonia"
    "services/slurm"
    "services/homepage"
    "services/jellyfin"
    "services/transmission"
    "services/fail2ban"
    "services/sops"
    "cloud-vps-control"
  ];
  tunables = {
    "headscale.enable" = true;
    "slurm.master" = true;
    "harmonia.enable" = true;
  };
}
