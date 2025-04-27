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

      common_ssh_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBZuf6oNuOd8+zyXt8Idh0Wx3irSx6IwcgxrEMfBgevV ehdemirli@proton.me";

      reverseTunnelClientPublicKey = common_ssh_key; # i feel lazy
      reverseTunnelClientPrivateKeyPath = "/persist/home/Desktop/dotfiles/secrets/.ssh/id_ed25519_proton"; # Path on reverse-ssh-client

      reverseSshBounceServerHost = "sshr.polarbearvuzi.com";
      reverseSshBounceServerPort = 42069;
      reverseSshBounceServerUser = "emre";

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
          } // argOverrides;
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
          };
        };

        server_local_x86 = mkSystem {
          baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
          hardwareConfigPath = ./hosts/server_local_x86/hardware-configuration.nix;
          system = "x86_64-linux";
          argOverrides = {
            hashedPassword = hashedServerPassword;
            authorizedKeys = [ common_ssh_key ];
            rootSshKeys = [ common_ssh_key ];
            hostName = "server-local-x86";
            maxJobs = 16;
            nixCores = 16;
            maxSubstitutionJobs = 256;
            swapSize = "32G";
            diskDevice = "/dev/nvme0n1";
            grubDevice = "nodev";

            reverseSshRemoteHost = reverseSshBounceServerHost;
            reverseSshRemotePort = reverseSshBounceServerPort;
            reverseSshRemoteUser = reverseSshBounceServerUser;
            reverseSshPrivateKeyPath = reverseTunnelClientPrivateKeyPath;

            extraImports = [
              ./hosts/common/services/warp.nix
              ./hosts/common/services/reverse-ssh-client.nix
            ];
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
            efiInstallAsRemovable = true;
            maxJobs = 4;
            nixCores = 4;
            maxSubstitutionJobs = 4;
            swapSize = "1G";
            diskDevice = "/dev/sda";
            grubDevice = "/dev/sda";

            extraImports = [ ./hosts/common/services/reverse-ssh-server.nix ];
            allowedPorts = [ reverseSshBounceServerPort ];
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
          };
        };
      };
    };
}
