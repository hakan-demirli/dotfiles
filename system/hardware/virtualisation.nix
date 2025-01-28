{ config, pkgs, ... }:
{
  # environment.systemPackages = with pkgs; [virt-manager virtualbox distrobox];
  programs.virt-manager.enable = true;

  virtualisation.libvirtd = {
    enable = true;
    # ISSUE: https://discourse.nixos.org/t/virt-manager-cannot-find-virtiofsd/26752/9
    qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
  };
  environment.systemPackages = with pkgs; [ virtiofsd ];

  # boot.extraModulePackages = with config.boot.kernelPackages; [virtualbox];
}
