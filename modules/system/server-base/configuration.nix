{
  inputs,
  ...
}:
{
  # Server base system configuration - shared across all servers
  config.flake.modules.nixos.system-server-base =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.system.server;
      common-packages = import (inputs.self + /pkgs/common/packages.nix) { inherit pkgs inputs; };
    in
    {
      # Server base system configuration - shared across all servers
      options.system.server = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable server base configuration";
        };
        hostName = lib.mkOption {
          type = lib.types.str;
          description = "Server hostname";
        };
      };

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
      ];

      config = lib.mkIf cfg.enable {
        system.fonts.minimal = true;

        networking = {
          inherit (cfg) hostName;
          networkmanager.enable = true;
        };

        systemd.defaultUnit = "multi-user.target";

        environment.systemPackages =
          common-packages.server-cli
          ++ (with pkgs; [
            home-manager
            git-crypt
          ]);

        boot.kernelPackages = pkgs.linuxPackages_latest;
      };
    };
}
