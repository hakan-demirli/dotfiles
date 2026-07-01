{
  id = "personal-server-dev";
  description = "Personal AMD workstation acting as a slurm compute node and submit host";
  kind = "nixos";
  node_role = "compute";
  modules = [
    "system/base"
    "system/server-base"
    "system/nix-settings"
    "system/impermanence"
    "system/ephemeral-root"
    "system/virtualisation"
    "services/tailscale"
    "services/apptainer"
    "services/slurm"
    "services/sops"
    "personal-server-dev"
  ];
}
