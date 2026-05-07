{
  inputs,
  lib,
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));

  vmProviderHardware = {
    qemu = {
      x86_64-linux = {
        initrdModules = [
          "ahci"
          "xhci_pci"
          "virtio_pci"
          "virtio_blk"
          "sr_mod"
        ];
        kernelModules = [ "kvm-amd" ];
      };
      aarch64-linux = {
        initrdModules = [
          "virtio_scsi"
          "sr_mod"
        ];
        kernelModules = [ ];
      };
    };
    oracle = {
      x86_64-linux = {
        initrdModules = [
          "ahci"
          "xhci_pci"
          "virtio_pci"
          "virtio_blk"
          "sr_mod"
        ];
        kernelModules = [ "kvm-amd" ];
      };
      aarch64-linux = {
        initrdModules = [
          "xhci_pci"
          "virtio_pci"
          "virtio_scsi"
          "usbhid"
        ];
        kernelModules = [ ];
      };
    };
  };

  mkServerHardware =
    hostCfg:
    { lib, config, ... }:
    {
      boot = {
        initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "ahci"
          "usbhid"
          "usb_storage"
          "sd_mod"
        ];
        initrd.kernelModules = [ "dm-snapshot" ];
        kernelModules = [ "kvm-${hostCfg.cpu}" ];
        extraModulePackages = [ ];
      };

      fileSystems = hostCfg.extraFileSystems or { };
      systemd.tmpfiles.rules = hostCfg.extraTmpfilesRules or [ ];

      networking.useDHCP = lib.mkDefault true;
      hardware.cpu.${hostCfg.cpu}.updateMicrocode =
        lib.mkDefault config.hardware.enableRedistributableFirmware;
    };

  mkVMHardware =
    hostCfg:
    let
      hw = vmProviderHardware.${hostCfg.provider}.${hostCfg.system};
    in
    { lib, ... }:
    {
      services.qemuGuest.enable = true;

      boot = {
        initrd.availableKernelModules = hw.initrdModules;
        initrd.kernelModules = [ "dm-snapshot" ];
        inherit (hw) kernelModules;
        extraModulePackages = [ ];
      };

      networking.useDHCP = lib.mkDefault true;
      networking.interfaces = lib.listToAttrs (
        map (iface: {
          name = iface;
          value.useDHCP = lib.mkDefault true;
        }) (hostCfg.networkInterfaces or [ ])
      );
    };

  mkContainers =
    users:
    let
      withContainer = lib.filter (e: e.value ? container) (lib.attrsToList users);
    in
    lib.listToAttrs (
      lib.imap0 (
        i: entry:
        let
          subnet = 100 + i;
        in
        lib.nameValuePair entry.name {
          autoStart = true;
          privateNetwork = true;
          hostAddress = "192.168.${toString subnet}.10";
          localAddress = "192.168.${toString subnet}.11";

          forwardPorts = [
            {
              protocol = "tcp";
              inherit (entry.value.container) hostPort;
              containerPort = 22;
            }
          ];

          config = _: {
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "yes";
            };

            users.users.${entry.name} = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
              inherit (entry.value) uid;
              openssh.authorizedKeys.keys = entry.value.authorizedKeys;
            };

            networking.firewall.allowedTCPPorts = [ 22 ];
            system.stateVersion = stateVersion;
          };
        }
      ) withContainer
    );

  stateVersion = "26.05";

in
{
  inherit publicData stateVersion;

  mkSharedServer =
    hostCfg: name:
    let
      users = hostCfg.users or { };
      userList = lib.attrValues users;
      userEntries = lib.attrsToList users;
      hasContainers = lib.any (e: e.value ? container) userEntries;
      sharedServerPassword = publicData.passwords.shared_server or publicData.passwords.server;
    in
    {
      system = "x86_64-linux";

      hardware = mkServerHardware hostCfg;

      module =
        { ... }:
        {
          imports =
            with inputs.self.modules.nixos;
            [
              system-server-base
              overlays
              services-tailscale
            ]
            ++ lib.optional (hostCfg ? extraConfig) hostCfg.extraConfig;

          time.timeZone = "Europe/Zurich";

          system = {
            server = {
              enable = true;
              hostName = name;
            };
            disko = {
              device = hostCfg.disk;
              swapSize = hostCfg.swapSize or "32G";
            };
            user = {
              username = "emre";
              uid = 1000;
              hashedPassword = sharedServerPassword;
              authorizedKeys = [ publicData.ssh.id_ed25519_proton_pub ];
              useHomeManager = true;
              homeManagerImports = [ inputs.self.modules.homeManager.server-headless ];
            };
          };

          users.users = lib.mapAttrs (_userName: userCfg: {
            isNormalUser = true;
            inherit (userCfg) uid;
            extraGroups = [ "networkmanager" ] ++ lib.optional (userCfg.root or false) "wheel";
            openssh.authorizedKeys.keys = userCfg.authorizedKeys;
            hashedPassword = sharedServerPassword;
          }) users;

          services = {
            ssh = {
              allowPasswordAuth = false;
              rootSshKeys = [
                publicData.ssh.id_ed25519_proton_pub
              ]
              ++ lib.concatMap (u: u.authorizedKeys) userList;
            };

            tailscale = {
              loginServerHost = "sshr.polarbearvuzi.com";
              useAuthKey = false;
              extraUpFlags = (hostCfg.tailscale or { }).extraUpFlags or [ "--advertise-tags=tag:shared-server" ];
            };
          };

          containers = mkContainers users;

          networking.nat = lib.mkIf hasContainers {
            enable = true;
            internalInterfaces = [ "ve-+" ];
            externalInterface = hostCfg.natInterface or "eth0";
          };

          nix.custom = {
            allowUnfree = true;
            cudaSupport = false;
            rocmSupport = false;
          };
        };
    };

  mkPersonalServer =
    hostCfg: name:
    let
      reverseSshBounceServerHost = "sshr.polarbearvuzi.com";
      reverseSshBounceServerUser = "emre";
      reverseSshBasePort = 42000;
    in
    {
      system = "x86_64-linux";

      hardware = mkServerHardware hostCfg;

      module =
        { ... }:
        {
          imports =
            with inputs.self.modules.nixos;
            [
              system-server-base
              overlays
              services-reverse-ssh-client
              services-warp
              services-tailscale
              services-sops
              services-slurm
              slurm-cluster-nodes
            ]
            ++ lib.optional (hostCfg ? extraConfig) hostCfg.extraConfig;

          time.timeZone = "Europe/Zurich";

          system = {
            server = {
              enable = true;
              hostName = name;
            };
            disko = {
              device = hostCfg.disk;
              swapSize = hostCfg.swapSize or "32G";
            }
            // lib.optionalAttrs (hostCfg ? additionalDisks) {
              inherit (hostCfg) additionalDisks;
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
              remoteHost = reverseSshBounceServerHost;
              remotePort = reverseSshBasePort + hostCfg.serverId;
              remoteUser = reverseSshBounceServerUser;
              privateKeyPath = "/home/${reverseSshBounceServerUser}/.ssh/id_ed25519_proton";
            };
            tailscale.loginServerHost = reverseSshBounceServerHost;

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
            hasTailscaleAuthority = true;
          };
        };
    };

  mkVM =
    hostCfg: name:
    let
      hostName = builtins.replaceStrings [ "_" ] [ "-" ] name;
    in
    {
      inherit (hostCfg) system;

      hardware = mkVMHardware hostCfg;

      module =
        { lib, ... }:
        {
          imports =
            with inputs.self.modules.nixos;
            [
              system-server-base
              overlays
            ]
            ++ map (s: inputs.self.modules.nixos.${s}) (hostCfg.extraServices or [ ]);

          time.timeZone = "Europe/Zurich";

          system = {
            server = {
              enable = true;
              inherit hostName;
            };
            disko = {
              device = hostCfg.disk;
              swapSize = hostCfg.swapSize or "8G";
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

          boot.loader = lib.mkIf (hostCfg.provider == "oracle" && hostCfg.system == "x86_64-linux") {
            grub.efiInstallAsRemovable = lib.mkForce true;
            efi = {
              efiSysMountPoint = "/boot";
              canTouchEfiVariables = lib.mkForce false;
            };
          };
        };
    };

  mkFleet =
    { inputs, lib }:
    fleet:
    let
      resolved = lib.mapAttrs (name: builderFn: builderFn name) fleet;
    in
    {
      flake.modules.nixos = lib.concatMapAttrs (name: host: {
        ${name} =
          { ... }:
          {
            imports = [
              host.module
              inputs.self.modules.nixos."${name}-hardware"
            ];
          };
        "${name}-hardware" = host.hardware;
      }) resolved;

      flake.nixosConfigurations = lib.foldlAttrs (
        acc: name: host:
        acc // inputs.self.lib.mkNixos host.system name
      ) { } resolved;
    };
}
