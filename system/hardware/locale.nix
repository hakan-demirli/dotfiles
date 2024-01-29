{
  pkgs,
  userSettings,
  systemSettings,
  ...
}: {
  time = {
    hardwareClockInLocalTime = false; # messes clock on windows
    timeZone = systemSettings.timezone;
  };

  # Select internationalisation properties.
  i18n = {
    defaultLocale = systemSettings.locale;
    extraLocaleSettings = {
      LC_ADDRESS = systemSettings.locale_extra;
      LC_IDENTIFICATION = systemSettings.locale_extra;
      LC_MEASUREMENT = systemSettings.locale_extra;
      LC_MONETARY = systemSettings.locale_extra;
      LC_NAME = systemSettings.locale_extra;
      LC_NUMERIC = systemSettings.locale_extra;
      LC_PAPER = systemSettings.locale_extra;
      LC_TELEPHONE = systemSettings.locale_extra;
      LC_TIME = systemSettings.locale_extra;
    };
  };
}
