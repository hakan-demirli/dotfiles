{
  flake.modules.nixos.system-virtualisation =
    { pkgs, ... }:
    {
      programs.virt-manager.enable = true;
      networking.firewall.trustedInterfaces = [ "virbr0" ];

      virtualisation.libvirtd = {
        enable = true;
        qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
        qemu.verbatimConfig = ''
          group = "users"
          remember_owner = 0
        '';
      };

      environment.systemPackages = with pkgs; [
        virtiofsd
        virt-viewer
      ];
    };
}
