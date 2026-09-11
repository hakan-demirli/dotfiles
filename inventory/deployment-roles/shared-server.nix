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
    "infra:system/impermanence"
    "infra:system/ephemeral-root"
    "infra:services/tailscale"
    "self:services/bootstrap-authentication"
    "self:deployment-roles/shared-server"
  ];
}
