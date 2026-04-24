{
  inputs,
  ...
}:
{
  flake.modules.nixos.system-laptop-base =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-base
        system-fonts
        system-locale
        system-impermanence
        system-ephemeral-root
        system-polkit
        system-boot-grub
        system-disko-btrfs-lvm
        user-base
        nix-settings
        overlays
        services-hyprland
        services-tailscale
        services-docker
        services-warp
        services-earlyoom
        services-yubikey
        services-sops
        system-battery
        system-gnupg
        system-virtualisation
        system-sound
        system-bluetooth
        system-automount
        system-v4l2loopback
      ];

      networking.networkmanager.enable = true;
      time.timeZone = "Europe/Zurich";

      systemd.services.NetworkManager-wait-online.enable = false;
      systemd.network.wait-online.enable = false;

      environment.systemPackages = with pkgs; [
        kitty
        foot
        xterm
        tofi
      ];

      documentation = {
        enable = true;
        nixos.enable = true;
      };

      hardware.keyboard.qmk.enable = true;
    };
}
