{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "prometheus-exporters";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        poetry-core
        setuptools
        psutil
        requests
        prometheus-client
      ]
    ))
  ];
  dontUnpack = true;

  src = ../scripts/python/prometheus;

  installPhase = ''
    mkdir -p $out/bin

    cp -r $src/exporter_window.py  $out/
    cp -r $src/exporter_network.py $out/
    cp -r $src/exporter_system.py  $out/

    ln -s $out/exporter_window.py  $out/bin/exporter_window
    ln -s $out/exporter_network.py $out/bin/exporter_network
    ln -s $out/exporter_system.py  $out/bin/exporter_system

    chmod +x $out/bin/exporter_window
    chmod +x $out/bin/exporter_network
    chmod +x $out/bin/exporter_system
  '';
}
