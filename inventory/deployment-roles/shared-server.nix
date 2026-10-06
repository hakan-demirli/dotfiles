{
  id = "shared-server";
  description = "Shared standalone server without a cluster scheduler";
  kind = "nixos";
  modules = [
    "infra:system/base"
    "infra:system/server-base"
    "infra:system/boot/grub"
    "infra:system/locale"
    "self:system/nix-settings"
    "self:services/journal-labels"
    "self:system/fleet-deploy"
    "infra:system/impermanence"
    "infra:system/ephemeral-root"
    "infra:services/tailscale"
    "infra:services/apptainer"
    "infra:services/podman"
    "self:services/bootstrap-authentication"
    "self:deployment-roles/shared-server"
  ];
}
