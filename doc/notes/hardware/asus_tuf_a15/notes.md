* Enable AMD Ryzen CPU Performance Scaling Driver (amd-pstate)
  * It depends on Collaborative Processor Performance Control (CPPC).
    * CPPC is disabled by default on this laptop and there is no BIOS option to enable it.
      * ```amd_pstate: the _CPC object is not present in SBIOS or ACPI disabled```
    * However, [Smokeless_UMAF](https://github.com/DavidS95/Smokeless_UMAF) can enable CPPC.
      * It works.
      * ```cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver```
