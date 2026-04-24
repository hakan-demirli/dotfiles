{
  inputs,
  ...
}:
let
  inherit (inputs.self.lib) publicData;
in
{
  flake.modules.nixos.l01 =
    {
      pkgs,
      ...
    }:
    {
      imports =
        with inputs.self.modules.nixos;
        [
          system-laptop-base
          services-slurm-client
          # Machine-specific modules
          l01-hardware
          system-nvidia
        ]
        ++ [
          (inputs.self + /pkgs/state_autocommit.nix)
          (inputs.self + /pkgs/github_backup.nix)
          (inputs.self + /pkgs/ntfy-listener.nix)
        ];

      networking.hostName = "l01";

      system = {
        disko = {
          device = "/dev/disk/by-id/nvme-KIOXIA-EXCERIA_SSD_X26FC0ZVF4M3";
          swapSize = "32G";
        };
        impermanence = {
          persistentDirs = [
            "/var/lib/libvirt"
            "/var/log"
            "/var/lib/bluetooth"
          ];
          extraPersistentUserDirs = [
            ".config/pulse"
            ".local/state/pipewire"
            ".local/state/wireplumber"
            ".mozilla"
          ];
        };
        user = {
          username = "emre";
          uid = 1000;
          hashedPassword = publicData.passwords.l01;
          useHomeManager = true;
          extraGroups = [ "kvm" ];
          homeManagerImports = [ inputs.self.modules.homeManager.desktop ];
        };
      };

      nix.custom = {
        allowUnfree = true;
        cudaSupport = false;
        rocmSupport = false;
      };

      services = {
        tailscale.reverseSshRemoteHost = "sshr.polarbearvuzi.com";

        slurm-client = {
          enable = true;
          masterHostname = "vm-oracle-aarch64";
        };

        # Prevent sleep. This machine's GPU stack crashes after suspend.
        logind.settings.Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchExternalPower = "ignore";
          HandleLidSwitchDocked = "ignore";
        };
      };

      boot = {
        binfmt.emulatedSystems = [ "aarch64-linux" ];
        kernel.sysctl = {
          "net.ipv4.ip_forward" = 1;
          "fs.file-max" = "20480000";
          "fs.inotify.max_user_watches" = "20480000";
          "fs.inotify.max_user_instances" = "20480000";
          "fs.inotify.max_queued_events" = "20480000";
          "kernel.perf_event_paranoid" = 1;
        };
        kernelPackages = pkgs.linuxPackages_latest;
        supportedFilesystems = [ "ntfs" ];
      };

    };
}
