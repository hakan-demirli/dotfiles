{
  inputs,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
  reverseSshBounceServerHost = "sshr.polarbearvuzi.com";
  reverseSshBounceServerUser = "emre";
  reverseSshBasePort = 42000;
  serverId = 1;
in
{
  flake.modules.nixos.s01 =
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
        s01-hardware
      ];

      networking.networkmanager.enable = true;

      time.timeZone = "Europe/Zurich";

      system = {
        server = {
          enable = true;
          hostName = "s01";
        };
        disko = {
          device = "/dev/nvme0n1";
          swapSize = "32G";
          additionalDisks = [ "/dev/nvme1n1" ];
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
          remotePort = reverseSshBasePort + serverId; # 42001
          remoteUser = reverseSshBounceServerUser;
          privateKeyPath = "/home/emre/.ssh/id_ed25519_proton";
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

      programs.nix-ld.enable = true;

      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    };
}
