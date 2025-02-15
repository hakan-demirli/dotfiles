{ pkgs, userSettings, ... }:
{
  programs.thunderbird = {
    enable = true;

    profiles.personal = {
      isDefault = true;
      # withExternalGnupg = true;
    };
  };
}
