{ pkgs, ... }:
{
  imports = [ ../system/power-profile.nix ];

  hardware.powerProfile = {
    backend = ./asus-tuf-a15-power.sh;
    runtimeInputs = [ pkgs.coreutils ];
  };
}
