{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  transferInbox = "/persist/home/emre/paths/Downloads/Inbox";
  tailnetDomain = "ts.sshr.polarbearvuzi.com";
  transferSources = [
    "vps-oracle-0.${tailnetDomain}"
    "server-dev-1.${tailnetDomain}"
  ];
in
{
  imports = [
    ../services/wifi-profiles.nix
    inputs.infra-lib.nixosModules.system-intel
    "${inputs.infra-lib}/modules/services/fprintd.nix"
    "${inputs.infra-lib}/modules/services/desktop/tablet.nix"
    ../system/overlays.nix
  ];

  services = {
    openssh.enable = lib.mkForce false;

    wifiProfiles = {
      enable = true;
      sopsFile = inputs.self + /secrets/wifi/networks.yaml;
      keyFile = "/home/emre/.config/sops/age/wifi.key";
    };

    rsyncd = {
      enable = true;
      socketActivated = true;
      settings = {
        globalSection = {
          uid = "emre";
          gid = "users";
          "use chroot" = true;
          "max connections" = 4;
          "reverse lookup" = true;
        };
        sections.inbox = {
          path = transferInbox;
          comment = "Write-only file inbox for trusted tailnet nodes";
          "read only" = false;
          "write only" = true;
          list = false;
          "hosts allow" = lib.concatStringsSep " " transferSources;
          "hosts deny" = "*";
          "incoming chmod" = "Du=rwx,Dgo=,Fu=rw,Fgo=";
          "munge symlinks" = true;
          "refuse options" = "delete delete-before delete-during delete-delay delete-after delete-excluded";
          timeout = 600;
        };
      };
    };

    slurm-client.enable = true;
    logind.settings.Login = {
      HandleLidSwitch = "suspend-then-hibernate";
      HandleLidSwitchExternalPower = "suspend-then-hibernate";
      HandleLidSwitchDocked = "ignore";
    };
  };

  systemd = {
    sockets.rsync = {
      after = [ "tailscaled.service" ];
      before = [ "shutdown.target" ];
      conflicts = [ "shutdown.target" ];
      requires = [ "tailscaled.service" ];
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = [ transferInbox ];
      };
      socketConfig.BindToDevice = "tailscale0";
    };

    tmpfiles.rules = [
      "d ${transferInbox} 0700 emre users -"
    ];

  };

  networking.useDHCP = lib.mkDefault true;

  environment.etc."libinput/local-overrides.quirks".text = ''
    [ELAN2513 Metapen MCP2 Stylus Pressure]
    MatchName=ELAN2513:00 04F3:4302 Stylus
    MatchBus=i2c
    AttrPressureRange=40:10
  '';

  boot = {
    kernelParams = [ "video.brightness_switch_enabled=0" ];
    binfmt.emulatedSystems = [
      "aarch64-linux"
      "riscv64-linux"
    ];
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
}
