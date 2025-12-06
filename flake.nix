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
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur.url = "github:hakan-demirli/NUR";
  };

  outputs =
    { nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      systemArgs = {

        laptop = {
          baseConfigPath = ./hosts/laptop/configuration.nix;
          hardwareConfigPath = ./hosts/laptop/hardware-configuration.nix;
          system = "x86_64-linux";
          argOverrides = {
            inherit hashedPassword;
            emulatedSystems = [ "aarch64-linux" ];
            reverseSshRemoteHost = reverseSshBounceServerHost;
            slurmClient = true;
            hardwareConfiguration = {
              cores = 16;
              ram_mb = 21000;
            };
            extraImports = [
              # ./pkgs/sshfs-mount.nix
            ];
          };
        };

        vm_oracle_aarch64 = {
          baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
          hardwareConfigPath = ./hosts/vm_oracle_aarch64/hardware-configuration.nix;
          system = "aarch64-linux";
          argOverrides = {
            hashedPassword = hashedServerPassword;
            authorizedKeys = [
              common_ssh_key
              gh_action_key
              reverseTunnelClientPublicKey
            ];
            rootSshKeys = [ common_ssh_key ];
            allowPasswordAuth = false;
            hostName = "vm-oracle-aarch64";
            emulatedSystems = [ "x86_64-linux" ];
            efiInstallAsRemovable = false;
            canTouchEfiVariables = true;
            swapSize = "1G";
            diskDevice = "/dev/sda";
            grubDevice = "/dev/sda";
            reverseSshRemoteHost = reverseSshBounceServerHost;

            hardwareConfiguration = {
              cores = 4;
              ram_mb = 21000;
            };
            slurmMaster = true;
            slurmNode = true;

            extraImports = [
              ./hosts/common/services/reverse-ssh-server.nix
              ./hosts/common/services/headscale.nix
              ./hosts/common/services/fail2ban.nix
              ./hosts/common/services/docker-registry.nix
              ./hosts/common/services/nix-serve.nix
              # ./pkgs/sshfs-mount.nix
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
            ++ (lib.genList (n: reverseSshBasePort + n + 1) (builtins.length localX86Servers));
          };
        };

        vm_oracle_x86 = {
          baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
          hardwareConfigPath = ./hosts/vm_oracle_x86/hardware-configuration.nix;
          system = "x86_64-linux";
          argOverrides = {
            hashedPassword = hashedServerPassword;
            authorizedKeys = [ common_ssh_key ];
            rootSshKeys = [ common_ssh_key ];
            hostName = "vm-oracle-x86";
            efiInstallAsRemovable = true;
            diskDevice = "/dev/sda";
            grubDevice = "/dev/sda";
            swapSize = "4G";

            hardwareConfiguration = {
              cores = 8;
              ram_mb = 8192;
            };
          };
        };

        vm_qemu_x86 = {
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

            hardwareConfiguration = {
              cores = 8;
              ram_mb = 8192;
            };
          };
        };

        vm_qemu_aarch64 = {
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

            hardwareConfiguration = {
              cores = 2;
              ram_mb = 4096;
            };
          };
        };
      }
      // localX86ServerArgs;

      localX86Servers = [
        {
          id = 1;
          name = "s01";
          disk = "/dev/nvme0n1";
          slurmNode = true;
          hardwareConfiguration = {
            cores = 16;
            ram_mb = 77000;
          };
        }
        {
          id = 2;
          name = "s02";
          disk = "/dev/sda";
          slurmNode = true;
          hardwareConfiguration = {
            cores = 8;
            ram_mb = 14500;
          };
        }
      ];

      slurmClusterHardware =
        let
          slurmClusterMembers = lib.filterAttrs (
            _hostname: args: (args.argOverrides.slurmNode or false) || (args.argOverrides.slurmMaster or false)
          ) systemArgs;
        in
        lib.mapAttrs (attrName: args: {
          hostName = args.argOverrides.hostName or attrName;
          inherit (args.argOverrides.hardwareConfiguration) cores ram_mb;
          isSlurmMaster = args.argOverrides.slurmMaster or false;
        }) slurmClusterMembers;

      hashedPassword = "$6$dxLcMi321Rg6B7Nu$tRRLCU/7AEFKg7HW56XIKkbtowfyX4uSOq0M8.pKRZIgg6FrdF9o19yAf1mEov.C.SnhSlXG48rmVbVFqtbEn1";
      hashedServerPassword = "$6$hjsD4y4Iy/9ql6dC$WYxNpnvlx9r6TbGwWcXMqzzsyzh6IvftawYlyvwB4/Zr21UNO5eyj87WB2JqcH.EoO3rmP10P5X/d0b6tNcSh/";
      common_ssh_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDDPkxYuzRBqtndEoRNx/ua5P0KCG9gMsCe77qf+2ie ehdemirli@proton.me";
      gh_action_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJc3ZOX/1j5c3hhDtVzckc9cxUybO0HwFvgrF+x+x6rr emre@laptop";
      reverseTunnelClientPublicKey = common_ssh_key;
      reverseTunnelClientPrivateKeyPath = "/home/emre/.ssh/id_ed25519_proton";
      reverseSshBounceServerHost = "sshr.polarbearvuzi.com";
      reverseSshBounceServerUser = "emre";
      reverseSshBasePort = 42000;

      localX86ServerArgs = lib.listToAttrs (
        map (server: {
          inherit (server) name;
          value = {
            baseConfigPath = ./hosts/vm_qemu_x86/configuration.nix;
            hardwareConfigPath = ./hosts/server_local_x86/hardware-configuration.nix;
            system = "x86_64-linux";
            argOverrides = {
              hashedPassword = hashedServerPassword;
              authorizedKeys = [ common_ssh_key ];
              rootSshKeys = [ common_ssh_key ];
              hostName = server.name;
              diskDevice = server.disk;
              reverseSshRemotePort = reverseSshBasePort + server.id;
              swapSize = "32G";
              grubDevice = "nodev";
              reverseSshRemoteHost = reverseSshBounceServerHost;
              reverseSshRemoteUser = reverseSshBounceServerUser;
              reverseSshPrivateKeyPath = reverseTunnelClientPrivateKeyPath;
              inherit (server) hardwareConfiguration;
              inherit (server) slurmNode;

              extraImports = [
                ./hosts/common/services/warp.nix
                ./hosts/common/services/tailscale.nix
                ./hosts/common/services/reverse-ssh-client.nix
              ];
              # ++ lib.optional (server.name != "s01") ./pkgs/sshfs-mount.nix;
            };
          };
        }) localX86Servers
      );

      mkSystem =
        args:
        nixpkgs.lib.nixosSystem {
          inherit (args) system;
          specialArgs = {
            inherit inputs;
          }
          // args.argOverrides;
          modules = [
            args.baseConfigPath
            args.hardwareConfigPath
            inputs.home-manager.nixosModules.home-manager
            inputs.disko.nixosModules.default
            inputs.impermanence.nixosModules.impermanence
            inputs.sops-nix.nixosModules.sops
            ./hosts/common/services/sops.nix
            ./overlay.nix
          ]
          ++ (args.argOverrides.extraImports or [ ]);
        };

      nixosConfigurations = lib.mapAttrs (
        _hostname: args:
        let
          isSlurmParticipant =
            (args.argOverrides.slurmNode or false) || (args.argOverrides.slurmMaster or false);
          isSlurmClientOnly = (args.argOverrides.slurmClient or false) && !isSlurmParticipant;
          finalArgs = args // {
            argOverrides = (args.argOverrides or { }) // {
              inherit slurmClusterHardware;

              maxJobs = args.argOverrides.hardwareConfiguration.cores;
              nixCores = args.argOverrides.hardwareConfiguration.cores;
              maxSubstitutionJobs = (args.argOverrides.hardwareConfiguration.cores or 1) * 4;

              extraImports =
                (args.argOverrides.extraImports or [ ])
                ++ (lib.optional isSlurmParticipant ./hosts/common/services/slurm.nix)
                ++ (lib.optional isSlurmClientOnly ./hosts/common/services/slurm-client.nix);
            };
          };
        in
        mkSystem finalArgs
      ) systemArgs;

      forEachSystem = systems: f: lib.genAttrs systems f;
      barebonePackages =
        pkgs:
        let
          userPackages = import ./users/common/packages.nix { inherit pkgs inputs; };
        in
        userPackages.dev-essentials
        ++ userPackages.editors
        ++ userPackages.lsp
        ++ userPackages.tools-cli
        ++ [
          pkgs.openssl
          pkgs.ncurses
          pkgs.direnv
          pkgs.starship
        ];

      devShells = forEachSystem [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend (
            lib.composeManyExtensions (import ./overlay.nix { }).nixpkgs.overlays
          );
        in
        {
          barebone = pkgs.mkShell {
            packages = barebonePackages pkgs;
          };
        }
      );

      packages = forEachSystem [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend (
            lib.composeManyExtensions (import ./overlay.nix { }).nixpkgs.overlays
          );
        in
        {
          barebone = pkgs.buildEnv {
            name = "barebone";
            paths = barebonePackages pkgs;
          };
        }
      );
    in
    {
      inherit nixosConfigurations;
      inherit devShells;
      inherit packages;
    };
}
