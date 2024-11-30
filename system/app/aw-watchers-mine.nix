{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "aw-watchers-mine";

  nativeBuildInputs = with pkgs; [ ];

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        poetry-core
        setuptools
        aw-client
        aw-core
        psutil
        requests
      ]
    ))
  ];
  dontUnpack = true;

  src = ../scripts/python/aw-watcher;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/aw-watcher-netstatus.py $out/
    cp -r $src/aw-watcher-system.py $out/
    ln -s $out/aw-watcher-netstatus.py $out/bin/aw-watcher-netstatus
    ln -s $out/aw-watcher-system.py $out/bin/aw-watcher-system
    chmod +x $out/bin/aw-watcher-netstatus
    chmod +x $out/bin/aw-watcher-system
  '';
}
