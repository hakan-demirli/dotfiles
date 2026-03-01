{
  inputs,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
  reverseSshBounceServerHost = "sshr.polarbearvuzi.com";
  reverseSshBounceServerUser = "emre";
  reverseSshBasePort = 42000;
  serverId = 2;
in
{
  flake.modules.nixos.s02 =
    { ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-server-base
        services-reverse-ssh-client
        services-warp
        services-tailscale
        services-sops
        services-slurm
        slurm-cluster-nodes
        s02-hardware
      ];

      time.timeZone = "Europe/Zurich";

      system = {
        server = {
          enable = true;
          hostName = "s02";
        };
        disko = {
          device = "/dev/sda";
          swapSize = "32G";
        };
        impermanence = {
          username = "emre";
          uid = 1000;
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

      services = {
        ssh = {
          allowPasswordAuth = false;
          rootSshKeys = [ publicData.ssh.id_ed25519_proton_pub ];
        };
        reverse-ssh-client = {
          enable = true;
          username = "emre";
          remoteHost = reverseSshBounceServerHost;
          remotePort = reverseSshBasePort + serverId; # 42002
          remoteUser = reverseSshBounceServerUser;
          privateKeyPath = "/home/${reverseSshBounceServerUser}/.ssh/id_ed25519_proton";
        };
        tailscale.reverseSshRemoteHost = reverseSshBounceServerHost;

        slurm-cluster = {
          enable = true;
          isMaster = false;
        };
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
