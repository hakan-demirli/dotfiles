{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "aw-manager";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        requests
      ]
    ))
  ];

  dontUnpack = true;

  installPhase = ''
    install -Dm755 ${../src/python/aw-manager.py} $out/bin/aw-manager;
  '';
}
