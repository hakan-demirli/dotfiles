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
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-base
        system-fonts
        system-locale
        system-impermanence
        system-boot-grub
        system-disko-btrfs-lvm
        user-base
        nix-settings
        services-ssh
        services-docker
        services-earlyoom
        services-reverse-ssh-client
        services-warp
        services-tailscale
        s01-hardware
      ];

      networking.hostName = "s01";
      networking.networkmanager.enable = true;
      time.timeZone = "Europe/Zurich";

      systemd.defaultUnit = "multi-user.target";

      system = {
        disko = {
          device = "/dev/nvme0n1";
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
      };

      users.users.emre.openssh.authorizedKeys.keys = [ publicData.ssh.id_ed25519_proton_pub ];

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
        username = "emre";
      };

      boot.kernelPackages = pkgs.linuxPackages_latest;
      system.stateVersion = "25.05";
    };
}
