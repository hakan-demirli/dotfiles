{
  timeZone,
  defaultLocale,
  extraLocaleSettings ? { },
  ...
}:
{
  time = {
    hardwareClockInLocalTime = false; # messes clock on windows
    inherit timeZone;
  };

  i18n = {
    inherit defaultLocale;
    supportedLocales = [
      "en_GB.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
    extraLocaleSettings = {
      LC_ADDRESS = "en_GB.UTF-8";
      LC_IDENTIFICATION = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_MONETARY = "en_GB.UTF-8";
      LC_NAME = "en_GB.UTF-8";
      LC_NUMERIC = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_TELEPHONE = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    } // extraLocaleSettings;
  };
}
