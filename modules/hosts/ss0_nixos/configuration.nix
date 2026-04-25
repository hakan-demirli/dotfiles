{
  inputs,
  ...
}:
let
  inherit (inputs.self.lib) publicData;
in
{
  flake.modules.nixos.ss0 =
    { ... }:
    {
      imports = with inputs.self.modules.nixos; [
        system-server-base
        overlays
        services-tailscale
        ss0-hardware
      ];

      time.timeZone = "Europe/Zurich";

      system = {
        server = {
          enable = true;
          hostName = "ss0";
        };
        disko = {
          device = "/dev/nvme0n1";
          swapSize = "32G";
        };
        user = {
          username = "emre";
          uid = 1000;
          hashedPassword = publicData.passwords.server;
          authorizedKeys = [ publicData.ssh.id_ed25519_proton_pub ];
          useHomeManager = true;
          homeManagerImports = [ inputs.self.modules.homeManager.server-headless ];
        };
      };

      users.users.um = {
        isNormalUser = true;
        uid = 1001;
        extraGroups = [
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
          loginServerHost = "sshr.polarbearvuzi.com";
          useAuthKey = false;
          extraUpFlags = [ "--advertise-tags=tag:shared-server" ];
        };
      };

      networking.nat = {
        enable = true;
        internalInterfaces = [ "ve-+" ];
        externalInterface = "eth0";
      };

      containers.emre = {
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

          users.users.emre = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            uid = 1000;
            openssh.authorizedKeys.keys = [ publicData.ssh.id_ed25519_proton_pub ];
          };

          networking.firewall.allowedTCPPorts = [ 22 ];
          system.stateVersion = inputs.self.lib.stateVersion;
        };
      };

      containers.um = {
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

          users.users.um = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            uid = 1001;
            openssh.authorizedKeys.keys = [ publicData.ssh.id_um_pub ];
          };

          networking.firewall.allowedTCPPorts = [ 22 ];
          system.stateVersion = inputs.self.lib.stateVersion;
        };
      };

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
      };
    };
}
