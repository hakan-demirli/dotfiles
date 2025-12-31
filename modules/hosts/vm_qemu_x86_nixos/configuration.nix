{
  inputs,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
in
{
  flake.modules.nixos.vm_qemu_x86 =
    {
      ...
    }:
    {
      imports = with inputs.self.modules.nixos; [
        system-server-base
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
        impermanence = {
          username = "emre";
          uid = 1000;
          persistentDirs = [ ];
        };
        user = {
          username = "emre";
          uid = 1000;
          hashedPassword = publicData.passwords.server;
          useHomeManager = true;
          homeManagerImports = [ inputs.self.modules.homeManager.server-headless ];
        };
        stateVersion = "25.05";
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
        username = "emre";
      };

    };
}
