{
  description = "dots";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
    };
    small-apps = {
      url = "github:hakan-demirli/small-apps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      # mkpasswd -m sha-512 "my_super_secret_pass"
      hashedPassword = "$6$dxLcMi321Rg6B7Nu$tRRLCU/7AEFKg7HW56XIKkbtowfyX4uSOq0M8.pKRZIgg6FrdF9o19yAf1mEov.C.SnhSlXG48rmVbVFqtbEn1";
      hashedServerPassword = "$6$hjsD4y4Iy/9ql6dC$WYxNpnvlx9r6TbGwWcXMqzzsyzh6IvftawYlyvwB4/Zr21UNO5eyj87WB2JqcH.EoO3rmP10P5X/d0b6tNcSh/";

      common_ssh_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDDPkxYuzRBqtndEoRNx/ua5P0KCG9gMsCe77qf+2ie ehdemirli@proton.me";

      reverseTunnelClientPublicKey = common_ssh_key; # i feel lazy
      reverseTunnelClientPrivateKeyPath = "/persist/home/emre/Desktop/dotfiles/secrets/.ssh/id_ed25519_proton"; # Path on reverse-ssh-client

      reverseSshBounceServerHost = "sshr.polarbearvuzi.com";
      reverseSshBounceServerUser = "emre";

      reverseSshBasePort = 42000;
      localX86Servers = [
        {
          id = 1;
          name = "s01";
          disk = "/dev/nvme0n1";
        }
        {
          id = 2;
          name = "s02";
          disk = "/dev/sda";
        }
      ];

      mkLocalX86Server =
        {
          id,
          name,
          disk,
        }:
        mkSystem {
          baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
          hardwareConfigPath = ./hosts/server_local_x86/hardware-configuration.nix;
          system = "x86_64-linux";
          argOverrides = {
            hashedPassword = hashedServerPassword;
            authorizedKeys = [ common_ssh_key ];
            rootSshKeys = [ common_ssh_key ];

            hostName = name;
            diskDevice = disk;
            reverseSshRemotePort = reverseSshBasePort + id; # 42001, 42002, etc.

            maxJobs = 16;
            nixCores = 16;
            maxSubstitutionJobs = 256;
            swapSize = "32G";
            grubDevice = "nodev";

            reverseSshRemoteHost = reverseSshBounceServerHost;
            reverseSshRemoteUser = reverseSshBounceServerUser;
            reverseSshPrivateKeyPath = reverseTunnelClientPrivateKeyPath;

            extraImports = [
              ./hosts/common/services/warp.nix
              ./hosts/common/services/tailscale.nix
              ./hosts/common/services/reverse-ssh-client.nix
            ];
          };
        };

      generatedLocalX86Configs = nixpkgs.lib.listToAttrs (
        map (server: {
          name = "${server.name}";
          value = mkLocalX86Server server;
        }) localX86Servers
      );

      mkSystem =
        {
          baseConfigPath,
          hardwareConfigPath,
          system ? throw "You must specify system (e.g. x86_64-linux)",
          argOverrides ? { },
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs system;
          }
          // argOverrides;
          modules = [
            baseConfigPath
            hardwareConfigPath
            inputs.home-manager.nixosModules.home-manager
            inputs.disko.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
            ./overlay.nix
          ];
        };
    in
    {
      nixosConfigurations = {

        laptop = mkSystem {
          baseConfigPath = ./hosts/laptop/configuration.nix;
          hardwareConfigPath = ./hosts/laptop/hardware-configuration.nix;
          system = "x86_64-linux";
          argOverrides = {
            hashedPassword = hashedPassword;
            emulatedSystems = [ "aarch64-linux" ];
            reverseSshRemoteHost = reverseSshBounceServerHost;
          };
        };

        vm_oracle_aarch64 = mkSystem {
          baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
          hardwareConfigPath = ./hosts/vm_oracle_aarch64/hardware-configuration.nix;
          system = "aarch64-linux";
          argOverrides = {
            hashedPassword = hashedServerPassword;
            authorizedKeys = [
              common_ssh_key
              reverseTunnelClientPublicKey
            ];
            rootSshKeys = [ common_ssh_key ];
            hostName = "vm-oracle-aarch64";
            emulatedSystems = [ "x86_64-linux" ];
            efiInstallAsRemovable = true;
            maxJobs = 4;
            nixCores = 4;
            maxSubstitutionJobs = 4;
            swapSize = "1G";
            diskDevice = "/dev/sda";
            grubDevice = "/dev/sda";
            reverseSshRemoteHost = reverseSshBounceServerHost;

            extraImports = [
              ./hosts/common/services/reverse-ssh-server.nix
              ./hosts/common/services/headscale.nix
            ];
            allowedUDPPorts = [
              3478 # STUN for Headscale/DERP
              41641 # Tailscale discovery
            ];
            allowedTCPPorts = [
              22 # SSH
              80 # Caddy (HTTP for certs)
              443 # Caddy (HTTPS for Headscale/DERP)
            ]
            ++ (nixpkgs.lib.genList (n: reverseSshBasePort + n + 1) (builtins.length localX86Servers));
          };
        };

        vm_oracle_x86 = mkSystem {
          baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
          hardwareConfigPath = ./hosts/vm_oracle_x86/hardware-configuration.nix;
          system = "x86_64-linux";
          argOverrides = {
            hashedPassword = hashedServerPassword;
            authorizedKeys = [ common_ssh_key ];
            rootSshKeys = [ common_ssh_key ];
            hostName = "vm-oracle-x86";
            efiInstallAsRemovable = true;
            maxJobs = 1;
            nixCores = 1;
            maxSubstitutionJobs = 1;
            diskDevice = "/dev/sda";
            grubDevice = "/dev/sda";
            swapSize = "4G";
          };
        };

        vm_qemu_x86 = mkSystem {
          baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
          hardwareConfigPath = ./hosts/vm_qemu_x86/hardware-configuration.nix;
          system = "x86_64-linux";
          argOverrides = {
            hashedPassword = hashedServerPassword;
            authorizedKeys = [ common_ssh_key ];
            rootSshKeys = [ common_ssh_key ];
            hostName = "vm-qemu-x86";
            diskDevice = "/dev/vda";
            grubDevice = "/dev/vda";
          };
        };

        vm_qemu_aarch64 = mkSystem {
          baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
          hardwareConfigPath = ./hosts/vm_qemu_aarch64/hardware-configuration.nix;
          system = "aarch64-linux";
          argOverrides = {
            hashedPassword = hashedServerPassword;
            authorizedKeys = [ common_ssh_key ];
            rootSshKeys = [ common_ssh_key ];
            hostName = "vm-qemu-aarch64";
            diskDevice = "/dev/vda";
            grubDevice = "/dev/vda";
          };
        };
      }
      // generatedLocalX86Configs;
    };
}
