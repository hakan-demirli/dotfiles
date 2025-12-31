{
  inputs,
  ...
}:
let
  publicData = builtins.fromTOML (builtins.readFile (inputs.self + /secrets/public.toml));
in
{
  flake.modules.nixos.vm_oracle_x86 =
    {
      pkgs,
      ...
    }:
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
        vm_oracle_x86-hardware
      ];

      networking.hostName = "vm-oracle-x86";
      networking.networkmanager.enable = true;
      time.timeZone = "Europe/Zurich";

      systemd.defaultUnit = "multi-user.target";

      system = {
        disko = {
          device = "/dev/sda";
          swapSize = "4G";
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

      services.ssh = {
        allowPasswordAuth = false;
        rootSshKeys = [ publicData.ssh.id_ed25519_proton_pub ];
      };

      users.users.emre.openssh.authorizedKeys.keys = [ publicData.ssh.id_ed25519_proton_pub ];

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
        username = "emre";
      };

      boot = {
        loader.efi.efiSysMountPoint = "/boot";
        loader.grub.efiInstallAsRemovable = true;
        kernelPackages = pkgs.linuxPackages_latest;
      };
      system.stateVersion = "25.05";
    };
}
