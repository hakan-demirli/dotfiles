{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "quantifyself";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        setuptools
        flask
        duckdb
        psutil
        requests
      ]
    ))
  ];
  dontUnpack = true;

  src = ../scripts/python/quantifyself;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/quantifyself_system.py    $out/
    cp -r $src/quantifyself_server.py    $out/
    cp -r $src/quantifyself_netstatus.py $out/
    cp -r $src/quantifyself_window.py    $out/

    ln -s $out/quantifyself_server.py    $out/bin/quantifyself_server
    ln -s $out/quantifyself_system.py    $out/bin/quantifyself_system
    ln -s $out/quantifyself_netstatus.py $out/bin/quantifyself_netstatus
    ln -s $out/quantifyself_window.py    $out/bin/quantifyself_window

    chmod +x $out/bin/quantifyself_server
    chmod +x $out/bin/quantifyself_system
    chmod +x $out/bin/quantifyself_netstatus
    chmod +x $out/bin/quantifyself_window
  '';
}
