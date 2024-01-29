{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  name = "youtube_sync";
  propagatedBuildInputs = [
    (pkgs.python3.withPackages (pythonPackages:
      with pythonPackages; [
        yt-dlp
      ]))
  ];
  dontUnpack = true;

  src = ../scripts/python/youtube_sync;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/* $out/
    ln -s $out/youtube_sync.py $out/bin/youtube_sync
    chmod +x $out/bin/youtube_sync
  '';
}
