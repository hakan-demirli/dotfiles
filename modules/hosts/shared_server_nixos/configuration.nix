{
  inputs,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
in
{
  flake.modules.nixos.shared_server =
    { ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-server-base
        services-tailscale
        services-sops
        shared_server-hardware
      ];

      time.timeZone = "Europe/Zurich";

      system = {
        server = {
          enable = true;
          hostName = "shared_server";
        };
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
          authorizedKeys = [ publicData.ssh.id_ed25519_proton_pub ];
          useHomeManager = true;
          homeManagerImports = [ inputs.self.modules.homeManager.server-headless ];
        };
        stateVersion = "25.05";
      };

      users.users.um = {
        isNormalUser = true;
        uid = 1001;
        extraGroups = [
          "wheel"
          "docker"
          "networkmanager"
        ];
        openssh.authorizedKeys.keys = [ publicData.ssh.id_um_pub ];
        hashedPassword = publicData.passwords.server;
      };

      services = {
        ssh = {
          allowPasswordAuth = false;
          rootSshKeys = [
            publicData.ssh.id_ed25519_proton_pub
            publicData.ssh.id_um_pub
          ];
        };

        tailscale = {
          enable = true;
          reverseSshRemoteHost = "sshr.polarbearvuzi.com";
          extraUpFlags = [ "--advertise-tags=tag:shared-server" ];
        };
      };

      networking.nat = {
        enable = true;
        internalInterfaces = [ "ve-+" ];
        externalInterface = "eth0";
      };

      containers.alice = {
        autoStart = true;
        privateNetwork = true;
        hostAddress = "192.168.100.10";
        localAddress = "192.168.100.11";

        forwardPorts = [
          {
            protocol = "tcp";
            hostPort = 2201;
            containerPort = 22;
          }
        ];

        config = _: {
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };

          users.users.alice = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            uid = 1001;
            openssh.authorizedKeys.keys = [ publicData.ssh.id_ed25519_proton_pub ];
          };

          networking.firewall.allowedTCPPorts = [ 22 ];
          system.stateVersion = "25.05";
        };
      };

      containers.bob = {
        autoStart = true;
        privateNetwork = true;
        hostAddress = "192.168.101.10";
        localAddress = "192.168.101.11";

        forwardPorts = [
          {
            protocol = "tcp";
            hostPort = 2202;
            containerPort = 22;
          }
        ];

        config = _: {
          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };

          users.users.bob = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            uid = 1002;
            openssh.authorizedKeys.keys = [ publicData.ssh.id_um_pub ];
          };

          networking.firewall.allowedTCPPorts = [ 22 ];
          system.stateVersion = "25.05";
        };
      };

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
        username = "emre";
      };
    };
}
