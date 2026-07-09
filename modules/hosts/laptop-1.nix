{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    inputs.infra-lib.nixosModules.system-intel
    "${inputs.infra-lib}/modules/services/fprintd.nix"
    "${inputs.infra-lib}/modules/services/desktop/tablet.nix"
  ];

  services.slurm-client = {
    enable = true;
    masterHostname = "vps-oracle-0";
  };

  users.users.emre.hashedPassword = "$6$dxLcMi321Rg6B7Nu$tRRLCU/7AEFKg7HW56XIKkbtowfyX4uSOq0M8.pKRZIgg6FrdF9o19yAf1mEov.C.SnhSlXG48rmVbVFqtbEn1";

  networking.useDHCP = lib.mkDefault true;

  environment.etc."libinput/local-overrides.quirks".text = ''
    [ELAN2513 Metapen MCP2 Stylus Pressure]
    MatchName=ELAN2513:00 04F3:4302 Stylus
    MatchBus=i2c
    AttrPressureRange=40:10
  '';

  system.impermanence.extraPersistentUserDirs = [
    ".config/pulse"
    ".local/state/pipewire"
    ".local/state/wireplumber"
    ".config/mozilla"
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleLidSwitchDocked = "ignore";
  };

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
