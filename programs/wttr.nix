{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  name = "wttr";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages:
      with pythonPackages; [
        requests
      ]))
  ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${../scripts/python/wttr.py} $out/bin/wttr;
  '';
}
