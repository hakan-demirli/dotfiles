{ pkgs, ... }:
{
  imports = [ ../system/power-profile.nix ];

  hardware.powerProfile = {
    backend = ./minisforum-ms-a2-power.sh;
    runtimeInputs = [ pkgs.coreutils ];
  };
}
