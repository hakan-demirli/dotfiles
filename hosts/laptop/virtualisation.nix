{ pkgs, ... }:
{
  # environment.systemPackages = with pkgs; [virt-manager virtualbox distrobox];
  programs.virt-manager.enable = true;
  networking.firewall.trustedInterfaces = [ "virbr0" ];

  virtualisation.libvirtd = {
    enable = true;
    # ISSUE: https://discourse.nixos.org/t/virt-manager-cannot-find-virtiofsd/26752/9
    qemu.vhostUserPackages = with pkgs; [ virtiofsd ];

    qemu.verbatimConfig = ''
      group = "users"
      remember_owner = 0
    '';
  };
  environment.systemPackages = with pkgs; [
    virtiofsd
    virt-viewer # multimonitor setup, ❯ remote-viewer spice://localhost:5900
  ];

  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";

  # Problematic. Permission issues.
  # virtualisation.docker.rootless = {
  #   enable = true;
  #   setSocketVariable = true;
  # };

  # boot.extraModulePackages = with config.boot.kernelPackages; [virtualbox];
}
