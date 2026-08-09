{
  id = "cloud-vps-control";
  description = "Cloud VPS control plane";
  kind = "nixos";
  modules = [
    "infra:system/base"
    "infra:system/server-base"
    "infra:system/impermanence"
    "infra:system/ephemeral-root"
    "self:system/nix-settings"
    "infra:services/headscale"
    "infra:services/tailscale"
    "infra:services/ntfy"
    "infra:services/reverse-ssh-server"
    "infra:services/harmonia"
    "infra:services/slurm"
    "self:services/homepage"
    "infra:services/jellyfin"
    "infra:services/transmission"
    "infra:services/fail2ban"
    "self:services/sops"
    "self:deployment-roles/cloud-vps-control"
  ];
}
