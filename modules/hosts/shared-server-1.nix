{ lib, ... }:
{
  boot = {
    kernel.sysctl = {
      "kernel.hardlockup_panic" = 1;
      "kernel.hung_task_all_cpu_backtrace" = 1;
      "kernel.hung_task_panic" = 1;
      "kernel.hung_task_timeout_secs" = 60;
      "kernel.panic_on_oops" = 1;
      "kernel.panic_on_rcu_stall" = 1;
      "kernel.panic_print" = 64;
      "kernel.softlockup_all_cpu_backtrace" = 1;
      "kernel.softlockup_panic" = 1;
      "kernel.sysrq" = 1;
    };
    kernelModules = [ "rtw88_8821cu" ];
    loader = {
      efi.canTouchEfiVariables = lib.mkForce false;
      systemd-boot.enable = lib.mkForce false;
      grub.default = lib.mkForce "0";
      grub.efiInstallAsRemovable = lib.mkForce true;
    };
  };

  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
  hardware.fpga = {
    enable = true;
    devices.v80 = {
      kind = "amd-alveo-v80";
      pciAddress = "0000:01:00.0";
      parentPciAddress = "0000:00:01.1";
    };
  };

  time.timeZone = "Europe/Zurich";

  services.journald.settings.Journal = {
    RateLimitBurst = 50000;
    RateLimitIntervalSec = "30s";
    SyncIntervalSec = "5s";
  };

  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    WatchdogDevice = "/dev/watchdog0";
  };
}
