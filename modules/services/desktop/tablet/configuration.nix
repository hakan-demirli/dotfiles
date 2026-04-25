{
  flake.modules.nixos.services-tablet =
    { pkgs, ... }:
    {
      hardware.sensor.iio.enable = true;

      environment.systemPackages = with pkgs; [
        wvkbd
      ];
    };
}
