{
  inputs,
  lib,
  ...
}:
let
  inherit (inputs.self.lib) publicData;
  reverseSshBounceServerHost = "sshr.polarbearvuzi.com";
  reverseSshBasePort = 42000;
in
{
  flake.nixosConfigurations = inputs.self.lib.mkNixos "aarch64-linux" "vm_oracle_aarch64";

  flake.modules.nixos.vm_oracle_aarch64-hardware =
    { lib, ... }:
    {
      services.qemuGuest.enable = true;

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "virtio_pci"
          "virtio_scsi"
          "usbhid"
        ];
        initrd.kernelModules = [ "dm-snapshot" ];
        kernelModules = [ ];
        extraModulePackages = [ ];
      };

      networking.useDHCP = lib.mkDefault true;
    };

  flake.modules.nixos.vm_oracle_aarch64 =
    { ... }:
    {
      imports =
        with inputs.self.modules.nixos;
        [
          system-server-base
          overlays
          services-reverse-ssh-server
          services-tailscale
          services-headscale
          services-fail2ban
          services-docker-registry
          services-harmonia
          services-sops
          services-slurm
          slurm-cluster-nodes
          services-ntfy
          services-homepage
          services-deasciifier
          services-jellyfin
          services-transmission
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
        reverse-ssh-server = {
          enable = true;
          allowedTCPPorts = [
            22
            80
            443
          ]
          ++ (lib.genList (n: reverseSshBasePort + n + 1) 10);
        };
        headscale-server = {
          enable = true;
          serverUrl = reverseSshBounceServerHost;
          allowedUDPPorts = [
            3478
            41641
          ];
        };
        tailscale.loginServerHost = reverseSshBounceServerHost;

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
        hasTailscaleAuthority = true;
        excludeSubstituters = [ "http://100.64.0.1:5101" ];
      };

      boot = {
        loader.efi.canTouchEfiVariables = true;
        loader.grub.efiInstallAsRemovable = false;
        binfmt.emulatedSystems = [ "x86_64-linux" ];
      };
    };
}
