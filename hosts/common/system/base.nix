{
  config,
  lib,
  ...
}:
{

  documentation = {
    enable = lib.mkDefault false;
    nixos.enable = lib.mkDefault false;
  };

  fonts.fontconfig.enable = true;

  programs = {
    bash.completion.enable = true;
    command-not-found.enable = false;
    fuse.userAllowOther = true;
  };

  services = {
    udisks2.enable = lib.mkDefault false;
    dbus.enable = true;
  };

  i18n.supportedLocales = lib.mkDefault [ (config.i18n.defaultLocale + "/UTF-8") ];

  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=${config.system.path}/bin"
  '';

  hardware.uinput.enable = true;

  boot.kernelParams = [
    "console=tty1"
    "quiet"
    "mitigations=off"
    "panic=30"
    "boot.panic_on_fail"
  ];
  boot.kernel.sysctl."vm.overcommit_memory" = "1";

  environment = {
    variables = {
      GC_INITIAL_HEAP_SIZE = "1M";
    };
    localBinInPath = true;
  };

  security = {
    pam.services.swaylock = { };
    rtkit.enable = lib.mkDefault false;
  };
}
