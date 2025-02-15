{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "html-preview-server";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        requests
        flask
        flask-cors
        flask-socketio
        eventlet
      ]
    ))
  ];

  dontUnpack = true;

  src = ../src/python/html-preview/server;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/main.py       $out
    # cp -r $src/favicon.ico   $out/bin

    ln -s $out/main.py       $out/bin/html-preview-server
    chmod +x $out/bin/html-preview-server
  '';
}
