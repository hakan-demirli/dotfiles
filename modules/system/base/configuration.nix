{
  flake.modules.nixos.system-base = { config, lib, ... }: {
    documentation = {
      enable = lib.mkDefault false;
      nixos.enable = lib.mkDefault false;
    };

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

    # increase open file limit, workaround https://discourse.nixos.org/t/unable-to-fix-too-many-open-files-error/27094/9
    systemd.settings.Manager.DefaultLimitNOFILE = 1048576;

    hardware.uinput.enable = true;

    boot.kernelParams = [
      "console=tty1"
      "quiet"
      "mitigations=off"
      "panic=30"
      "boot.panic_on_fail"
    ];
    boot.kernel.sysctl."vm.overcommit_memory" = "0";

    environment = {
      variables = {
        GC_INITIAL_HEAP_SIZE = "1M";
      };
      localBinInPath = true;
    };

    security = {
      pam = {
        services.swaylock = { };
        # increase open file limit, workaround https://discourse.nixos.org/t/unable-to-fix-too-many-open-files-error/27094/9
        loginLimits = [
          {
            domain = "*";
            type = "hard";
            item = "nofile";
            value = "1048576";
          }
        ];
      };

      rtkit.enable = lib.mkDefault false;
    };
  };
}
