{
  inputs,
  lib,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
  reverseSshBounceServerHost = "sshr.polarbearvuzi.com";
  reverseSshBasePort = 42000;
in
{
  flake.modules.nixos.vm_oracle_aarch64 =
    { ... }:
    {
      imports =
        with inputs.self.modules.nixos;
        [
          system-server-base
          services-reverse-ssh-server
          services-tailscale
          services-headscale
          services-fail2ban
          services-docker-registry
          services-nix-serve
          services-sops
          services-slurm
          slurm-cluster-nodes
          services-ntfy
          vm_oracle_aarch64-hardware
        ]
        ++ [
          (inputs.self + /pkgs/github_backup.nix)
        ];

      time.timeZone = "Europe/Zurich";

      system = {
        server = {
          enable = true;
          hostName = "vm-oracle-aarch64";
        };
        disko = {
          device = "/dev/sda";
          swapSize = "1G";
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
        reverse-ssh-server = {
          enable = true;
          allowedTCPPorts = [
            22 # SSH
            80 # HTTP
            443 # HTTPS
          ]
          ++ (lib.genList (n: reverseSshBasePort + n + 1) 10); # Ports 42001-42010
        };
        headscale-server = {
          enable = true;
          serverUrl = reverseSshBounceServerHost;
          allowedUDPPorts = [
            3478 # STUN
            41641 # Tailscale discovery
          ];
        };
        tailscale.reverseSshRemoteHost = reverseSshBounceServerHost;

        slurm-cluster = {
          enable = true;
          isMaster = true;
        };
      };

      users.users.emre.openssh.authorizedKeys.keys = [
        publicData.ssh.id_ed25519_proton_pub
        publicData.ssh.gh_action_key_pub
      ];

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
        username = "emre";
        # Don't substitute from self - this IS the binary cache server
        excludeSubstituters = [ "http://100.64.0.1:5101" ];
      };

      boot = {
        loader.efi.canTouchEfiVariables = true;
        loader.grub.efiInstallAsRemovable = false;
        binfmt.emulatedSystems = [ "x86_64-linux" ];
      };

    };
}
