{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "aw-settings";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        requests
      ]
    ))
  ];

  dontUnpack = true;

  installPhase = ''
    install -Dm755 ${../scripts/python/aw-settings.py} $out/bin/aw-settings;
  '';
}
