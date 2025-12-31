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
        services-reverse-ssh-server
        services-headscale
        services-fail2ban
        services-docker-registry
        services-nix-serve
        vm_oracle_aarch64-hardware
      ];

      networking.hostName = "vm-oracle-aarch64";
      networking.networkmanager.enable = true;
      time.timeZone = "Europe/Zurich";

      systemd.defaultUnit = "multi-user.target";

      system = {
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
      };

      boot = {
        loader.efi.canTouchEfiVariables = true;
        loader.grub.efiInstallAsRemovable = false;
        binfmt.emulatedSystems = [ "x86_64-linux" ];
        kernelPackages = pkgs.linuxPackages_latest;
      };
      system.stateVersion = "25.05";
    };
}
