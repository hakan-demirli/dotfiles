{
  inputs,
  lib,
  ...
}:
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

  config.flake.modules.nixos.system-server-base = { config, pkgs, lib, ... }:
  let
    cfg = config.system.server;
  in
  lib.mkIf cfg.enable {
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

    networking = {
      hostName = cfg.hostName;
      networkmanager.enable = true;
    };

    # Headless server target
    systemd.defaultUnit = "multi-user.target";

    # Basic packages for a headless server
    environment.systemPackages = with pkgs; [
      home-manager
      git
      btop
      fzf
      git-crypt
      wget
      neovim
      file
    ];

    boot.kernelPackages = pkgs.linuxPackages_latest;
  };
}
