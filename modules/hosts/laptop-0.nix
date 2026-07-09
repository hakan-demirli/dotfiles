{
  pkgs,
  lib,
  inputs,
  host,
  cluster,
  ...
}:
let
  hostCluster =
    if cluster.hostToCluster ? ${host.id} then
      cluster.clusters.${cluster.hostToCluster.${host.id}}
    else
      throw "laptop-0: host '${host.id}' is not attached to any cluster.";

  controllers = hostCluster.scheduler.controllers;
  masterHostname =
    if controllers == [ ] then
      throw "laptop-0: cluster '${hostCluster.id}' has no scheduler.controllers declared."
    else
      builtins.head controllers;

  nodeAttrsFor =
    hid:
    let
      h = cluster.hosts.${hid};
    in
    {
      hostName = hid;
      sockets = h.hardware.cpu_sockets;
      coresPerSocket = h.hardware.cpu_cores_per_socket;
      threadsPerCore = h.hardware.cpu_threads_per_core;
      cpuLogicalCount = h.hardware.cpu_logical_count;
      ramMb = h.hardware.ram_gib * 1024;
    };

  clusterNodes = map nodeAttrsFor cluster.hostsByCluster.${hostCluster.id};
in
{
  imports = [
    inputs.infra-lib.nixosModules.system-amd-graphics
    inputs.infra-lib.nixosModules.system-nvidia
    "${inputs.infra-lib}/modules/services/desktop/remotedesktop.nix"
    "${inputs.infra-lib}/modules/services/slurm.nix"
    ../services/remotedesktop-session.nix
    ../system/overlays.nix
  ];

  services.slurm-cluster = {
    enable = true;
    isMaster = false;
    inherit masterHostname;
    inherit clusterNodes;
  };

  users.users.emre.hashedPassword = "$6$dxLcMi321Rg6B7Nu$tRRLCU/7AEFKg7HW56XIKkbtowfyX4uSOq0M8.pKRZIgg6FrdF9o19yAf1mEov.C.SnhSlXG48rmVbVFqtbEn1";

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "ahci"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];
    kernelModules = [ "kvm-amd" ];
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
    supportedFilesystems = [ "ntfs" ];
  };

  fileSystems."/mnt/second" = {
    device = "/dev/disk/by-uuid/120CC7A90CC785E7";
    fsType = "ntfs-3g";
    options = [
      "rw"
      "uid=1000"
    ];
  };

  networking.useDHCP = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;

  system.impermanence.extraPersistentUserDirs = [
    ".config/pulse"
    ".local/state/pipewire"
    ".local/state/wireplumber"
    ".config/mozilla"
    ".config/sunshine"
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  specialisation.sunshine.configuration = {
    environment.etc."specialization".text = "sunshine";

    services = {
      displayManager.sddm.enable = lib.mkForce false;
      xserver.enable = lib.mkForce false;

      remotedesktop = {
        modeOverride = "headless";
        connector = "HDMI-A-1";
        resolution = "2880x1800@60";
        drmDevice = "/dev/dri/card1";
        edidBase64 = "AP///////wBMg6pBAAAAAAAgAQS1HhN4A8/RrlE+tiMLUFQAAAABAQEBAQEBAQEBAQEBAQEBy/5AZLAIGHAgCIgALr0QAAAby/5AZLAIyHogCIgALr0QAAAbAAAA/QAweNraQgEAAAAAAAAAAAAAAgABAAAZlsg6FUbIAAAAAT1wIHkCACAADLpBWapBAAAAAAAWACEAHbgLbAdACwgHAO7qUOzTtj1CCwFFVEBe0GAYECN4JgAJBwYDAAAAUAAAIgAU5/MJhT8LYwAfAAcABwcXAAcABwCBAB9zGgAAAwMweACgdAJgAngAAAAAjeMFgADmBgUBdGACAAAAAAAJkA==";
      };
    };
  };
}
