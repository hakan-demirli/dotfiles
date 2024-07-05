{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "update_wp";
  propagatedBuildInputs = [
    pkgs.swww
    (pkgs.python3.withPackages (
      pythonPackages: with pythonPackages; [
        pillow
        requests
        google-auth-oauthlib
        google-api-python-client
      ]
    ))
  ];
  dontUnpack = true;

  src = ../scripts/python/update_wp;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/* $out/
    ln -s $out/update_wp.py $out/bin/update_wp
    chmod +x $out/bin/update_wp
  '';
}
