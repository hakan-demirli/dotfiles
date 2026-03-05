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

      # Fix https://github.com/NixOS/nixpkgs/issues/496836
      systemd.services.virt-secret-init-encryption = {
        serviceConfig = {
          ExecStart = [
            "" # Clear the existing ExecStart
            "${pkgs.bash}/bin/sh -c 'umask 0077 && (${pkgs.coreutils}/bin/dd if=/dev/random status=none bs=32 count=1 | ${pkgs.systemd}/bin/systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'"
          ];
        };
      };

      environment.systemPackages = with pkgs; [
        virtiofsd
        virt-viewer
      ];
    };
}
