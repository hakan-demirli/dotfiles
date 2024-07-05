{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  name = "youtube_sync";
  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages: with pythonPackages; [ yt-dlp ]))
  ];
  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${../scripts/python/youtube_sync.py} $out/bin/youtube_sync;
  '';
}
