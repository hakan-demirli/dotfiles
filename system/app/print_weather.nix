{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "print_weather";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages: with pythonPackages; [ requests ]))
  ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${../scripts/python/print_weather.py} $out/bin/print_weather;
  '';
}
