{
  id = "server-dev";
  description = "Individually-used workstation acting as a slurm compute node and submit host";
  kind = "nixos";
  modules = [
    "infra:system/base"
    "infra:system/server-base"
    "self:system/nix-settings"
    "infra:system/impermanence"
    "infra:system/ephemeral-root"
    "infra:system/virtualisation"
    "infra:services/tailscale"
    "infra:services/apptainer"
    "infra:services/slurm"
    "self:services/sops"
    "self:deployment-roles/server-dev"
  ];
}
