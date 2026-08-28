{
  id = "laptop";
  description = "Laptop (mobile, hibernates, tailnet-attached)";
  kind = "nixos";
  modules = [
    "infra:system/base"
    "infra:system/laptop-base"
    "infra:system/fonts"
    "infra:system/locale"
    "infra:system/sound"
    "infra:system/bluetooth"
    "infra:system/polkit"
    "infra:system/battery"
    "infra:system/hibernation"
    "infra:system/impermanence"
    "infra:system/ephemeral-root"
    "infra:system/gnupg"
    "infra:system/virtualisation"
    "infra:system/automount"
    "infra:system/v4l2loopback"
    "self:system/nix-settings"
    "infra:services/desktop/hyprland"
    "infra:services/tailscale"
    "infra:services/slurm-client"
    "infra:services/yubikey"
    "self:services/sops"
    "infra:services/apptainer"
    "infra:services/earlyoom"
    "self:deployment-roles/laptop"
  ];
}
