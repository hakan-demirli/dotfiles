{
  inputs,
  ...
}:
let
  inherit (inputs.self.lib) publicData;
in
{
  flake.modules.nixos.vm_qemu_x86 =
    {
      ...
    }:
    {
      imports = with inputs.self.modules.nixos; [
        system-server-base
        overlays
        vm_qemu_x86-hardware
      ];

      time.timeZone = "Europe/Zurich";

      system = {
        server = {
          enable = true;
          hostName = "vm-qemu-x86";
        };
        disko = {
          device = "/dev/vda";
          swapSize = "8G";
        };
        user = {
          username = "emre";
          uid = 1000;
          hashedPassword = publicData.passwords.server;
          useHomeManager = true;
          homeManagerImports = [ inputs.self.modules.homeManager.server-headless ];
        };
      };

      services.ssh = {
        allowPasswordAuth = false;
        rootSshKeys = [ publicData.ssh.id_ed25519_proton_pub ];
      };

      users.users.emre.openssh.authorizedKeys.keys = [ publicData.ssh.id_ed25519_proton_pub ];

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
      };

    };
}
