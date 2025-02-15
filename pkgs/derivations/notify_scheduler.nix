{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "notify_scheduler";

  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages: with pythonPackages; [ requests ]))
  ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${../src/python/notify_scheduler.py} $out/bin/notify_scheduler;
  '';
}
