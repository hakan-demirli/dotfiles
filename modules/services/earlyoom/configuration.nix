{
  flake.modules.nixos.services-earlyoom = { ... }: {
    services.earlyoom = {
      enable = true;
      freeMemThreshold = 10;
      freeSwapThreshold = 10;
      freeMemKillThreshold = 5;
      freeSwapKillThreshold = 5;
      enableNotifications = false;
      extraArgs = [
        "-g"
        "--avoid"
        "^(kitty|ssh|sshd|systemd|systemd-logind|sddm|Hyprland|Xorg|waybar|scrd|dbus-daemon|gpg-agent|ssh-agent)$"
        "--prefer"
        "^(electron|chrom|java|node|nix-daemon|cc1plus|rustc|cargo|gcc)$"
      ];
    };
  };
}
