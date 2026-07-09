{
  id = "personal-laptop";
  description = "Personal laptop (mobile, hibernates, tailnet-attached)";
  kind = "nixos";
  node_role = "personal";
  modules = [
    "system/base"
    "system/laptop-base"
    "system/fonts"
    "system/locale"
    "system/sound"
    "system/bluetooth"
    "system/polkit"
    "system/battery"
    "system/hibernation"
    "system/impermanence"
    "system/ephemeral-root"
    "system/gnupg"
    "system/virtualisation"
    "system/automount"
    "system/v4l2loopback"
    "system/nix-settings"
    "services/desktop/hyprland"
    "services/tailscale"
    "services/slurm-client"
    "services/yubikey"
    "services/sops"
    "services/apptainer"
    "services/earlyoom"
    "personal-laptop"
  ];
}
