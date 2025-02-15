{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "waybar_timer";

  nativeBuildInputs = with pkgs; [ zenity ];

  propagatedBuildInputs = [
    pkgs.python3
    pkgs.ffmpeg-full # full version for ffplay
  ];

  dontUnpack = true;

  installPhase = ''
    install -Dm755 ${../scripts/python/waybar_timer.py} $out/bin/waybar_timer;
  '';

  postFixup = ''
    substituteInPlace $out/bin/waybar_timer \
      --replace 'ZENITY = "zenity"' 'ZENITY = "${pkgs.zenity}/bin/zenity"'
  '';
}
