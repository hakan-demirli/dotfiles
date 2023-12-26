{pkgs, ...}: {
  gtasks_overlay = pkgs.stdenv.mkDerivation {
    name = "gtasks_overlay";
    propagatedBuildInputs = [
      (pkgs.python3.withPackages (pythonPackages:
        with pythonPackages; [
          consul
          six
          requests2
        ]))
    ];
    dontUnpack = true;
    installPhase = "install -Dm755 ${./scripts/python/gtasks_overlay.py} $out/bin/gtasks_overlay";
  };
}
