{
  inputs,
  ...
}:
let
  inherit (inputs.self.lib) publicData;
in
{
  flake.modules.nixos.l02 =
    { pkgs, ... }:
    {
      imports =
        with inputs.self.modules.nixos;
        [
          system-laptop-base
          services-fprintd
          services-slurm-client
          l02-hardware
        ]
        ++ [
          (inputs.self + /pkgs/state_autocommit.nix)
          (inputs.self + /pkgs/github_backup.nix)
          (inputs.self + /pkgs/ntfy-listener.nix)
        ];

      networking.hostName = "l02";

      system = {
        disko = {
          device = "/dev/disk/by-id/nvme-PC_SN8000S_SDEPNRG-2T00-1006_25290K800525";
          swapSize = "32G";
        };
        impermanence = {
          persistentDirs = [
            "/var/lib/libvirt"
            "/var/log"
            "/var/lib/bluetooth"
            "/var/lib/fprint"
          ];
          extraPersistentUserDirs = [
            ".config/pulse"
            ".local/state/pipewire"
            ".local/state/wireplumber"
            ".config/mozilla"
          ];
        };
        user = {
          username = "emre";
          uid = 1000;
          hashedPassword = publicData.passwords.l02;
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
        supportedFilesystems = [
          "ntfs"
          "xfs"
        ];
      };
    };
}
