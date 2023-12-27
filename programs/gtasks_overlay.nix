{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  name = "gtasks_overlay";
  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages:
      with pythonPackages; [
        pillow
        google-auth-oauthlib
        google-api-python-client
      ]))
  ];
  dontUnpack = true;

  src = ../scripts/python/gtasks;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/* $out/
    ln -s $out/gtasks_overlay.py $out/bin/gtasks_overlay
    chmod +x $out/bin/gtasks_overlay
  '';
}
