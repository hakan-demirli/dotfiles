{ lib, ... }:
{
  services = {
    openssh.settings.PermitRootLogin = lib.mkForce "no";
    sops.bootstrap.passwordAccount = "owner";
    tailscale.loginServerHost = "sshr.polarbearvuzi.com";
  };

  networking.networkmanager.enable = true;
  programs.nix-ld.enable = true;

  security.sudo.wheelNeedsPassword = true;

  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
  };
}
