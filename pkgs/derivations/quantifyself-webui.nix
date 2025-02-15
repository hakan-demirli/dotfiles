{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "quantifyself";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        setuptools
        flask-cors
        flask
        duckdb
        psutil
        requests
      ]
    ))
  ];
  dontUnpack = true;

  src = ../scripts/python/quantifyself-webui;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/static                    $out/bin/static
    cp -r $src/quantifyself-webui.py     $out/

    ln -s $out/quantifyself-webui.py     $out/bin/quantifyself-webui
    chmod +x $out/bin/quantifyself-webui
  '';
}
