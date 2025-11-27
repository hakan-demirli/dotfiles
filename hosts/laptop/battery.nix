_: {
  services.power-profiles-daemon.enable = false;
  powerManagement.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      TLP_PERSISTENT_DEFAULT = 0;

      # Nvidia GPU goes full throttle without this
      RUNTIME_PM_ON_AC = "auto";

      PLATFORM_PROFILE_ON_AC = "balanced";
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
      CPU_BOOST_ON_AC = 1;
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;

      PLATFORM_PROFILE_ON_BAT = "low-power";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_BOOST_ON_BAT = 0;
    };
  };
}
