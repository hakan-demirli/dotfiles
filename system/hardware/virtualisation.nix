{ config, pkgs, ... }:
{
  # environment.systemPackages = with pkgs; [virt-manager virtualbox distrobox];
  programs.virt-manager.enable = true;
  virtualisation.libvirtd.enable = true;
  environment.systemPackages = with pkgs; [ virtiofsd ];

  # boot.extraModulePackages = with config.boot.kernelPackages; [virtualbox];
}
