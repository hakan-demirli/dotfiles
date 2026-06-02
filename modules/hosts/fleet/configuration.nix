{
  inputs,
  lib,
  ...
}:
let
  builders = import ../../nix/flake-parts/_builders.nix { inherit inputs lib; };
  inherit (builders)
    publicData
    mkSharedServer
    mkPersonalServer
    mkVM
    ;
  mkFleet = builders.mkFleet { inherit inputs lib; };
in
mkFleet {

  ss0 = mkSharedServer {
    cpu = "intel";
    disk = "/dev/disk/by-id/nvme-SK_hynix_BC711_HFM512GD3JX013N_FYC6N012211306C69";
    extraServices = [ "system-virtualisation" ];
    extraTmpfilesRules = [
      "d /persist/xilinx 0755 emre users -"
    ];
    extraConfig = {
      system.impermanence.extraPersistentUserDirs = [
        ".Xilinx"
        "vivado-env"
      ];

      powerManagement.cpuFreqGovernor = "performance";
    };
    users = {
      emre = {
        uid = 1000;
        authorizedKeys = [ publicData.ssh.id_ed25519_proton_pub ];
        container = {
          hostPort = 2201;
        };
      };
      um = {
        uid = 1001;
        authorizedKeys = [ publicData.ssh.id_um_pub ];
        container = {
          hostPort = 2202;
        };
      };
    };
  };

  ss1 = mkSharedServer {
    cpu = "intel";
    disk = "/dev/disk/by-id/nvme-WD_BLACK_SN7100_1TB_25422J805576";
    extraServices = [ "system-virtualisation" ];
    extraTmpfilesRules = [
      "d /persist/xilinx 0755 emre users -"
    ];
    extraConfig = {
      system.impermanence.extraPersistentUserDirs = [
        ".Xilinx"
        "vivado-env"
      ];

      powerManagement.cpuFreqGovernor = "performance";
    };
  };

  s01 = mkPersonalServer {
    cpu = "amd";
    disk = "/dev/nvme0n1";
    serverId = 1;
    additionalDisks = [ "/dev/nvme1n1" ];
    extraConfig =
      { ... }:
      {
        imports = with inputs.self.modules.nixos; [
          system-amd-graphics
          system-sound
          services-remotedesktop
        ];

        networking.networkmanager.enable = true;
        programs.nix-ld.enable = true;
        boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

        system.impermanence.extraPersistentUserDirs = [
          ".config/sunshine"
        ];

        services.remotedesktop = {
          enable = true;
          headless = true;
          connector = "DP-1";
          resolution = "1920x1080@60";
          edidBase64 = "AP///////wBMg6pBAAAAAAAgAQS1HhN4A8/RrlE+tiMLUFQAAAABAQEBAQEBAQEBAQEBAQEBy/5AZLAIGHAgCIgALr0QAAAby/5AZLAIyHogCIgALr0QAAAbAAAA/QAweNraQgEAAAAAAAAAAAAAAgABAAAZlsg6FUbIAAAAAT1wIHkCACAADLpBWapBAAAAAAAWACEAHbgLbAdACwgHAO7qUOzTtj1CCwFFVEBe0GAYECN4JgAJBwYDAAAAUAAAIgAU5/MJhT8LYwAfAAcABwcXAAcABwCBAB9zGgAAAwMweACgdAJgAngAAAAAjeMFgADmBgUBdGACAAAAAAAJkA==";
        };
      };
  };

  s02 = mkPersonalServer {
    cpu = "amd";
    disk = "/dev/sda";
    serverId = 2;
    extraFileSystems = {
      "/mnt/hdd1" = {
        device = "/dev/disk/by-uuid/bc61c6f2-683e-4d24-9ad7-f76debff7d90";
        fsType = "btrfs";
        options = [
          "compress=zstd"
          "autodefrag"
          "noatime"
          "nofail"
        ];
      };
      "/mnt/hdd2" = {
        device = "/dev/disk/by-uuid/27feb42b-4406-4e68-ba6f-b29cb9d12d75";
        fsType = "btrfs";
        options = [
          "compress=zstd"
          "autodefrag"
          "noatime"
          "nofail"
        ];
      };
    };
    extraTmpfilesRules = [
      "d /mnt/hdd1 0775 emre users -"
      "d /mnt/hdd2 0775 emre users -"
    ];
  };

  vm_qemu_x86 = mkVM {
    system = "x86_64-linux";
    provider = "qemu";
    disk = "/dev/vda";
    networkInterfaces = [ "enp1s0" ];
  };

  vm_qemu_aarch64 = mkVM {
    system = "aarch64-linux";
    provider = "qemu";
    disk = "/dev/vda";
    extraServices = [ "services-sops" ];
  };

  vm_oracle_x86 = mkVM {
    system = "x86_64-linux";
    provider = "oracle";
    disk = "/dev/sda";
    swapSize = "4G";
    networkInterfaces = [ "enp1s0" ];
    extraServices = [ "services-sops" ];
  };

}
