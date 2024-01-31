{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  name = "auto_refresh";

  nativeBuildInputs = with pkgs; [
    wrapGAppsHook
    gobject-introspection
    libgudev
    libnotify
    gnused
  ];
  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages:
      with pythonPackages; [
        pygobject3
      ]))
  ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${../scripts/python/auto_refresh.py} $out/bin/auto_refresh;
  '';
}
