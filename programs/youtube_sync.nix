{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  name = "ics_overlay";
  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages:
      with pythonPackages; [
        pillow
        requests
      ]))
  ];
  dontUnpack = true;

  src = ../scripts/python/ics;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/* $out/
    ln -s $out/ics_overlay.py $out/bin/ics_overlay
    chmod +x $out/bin/ics_overlay
  '';
}
