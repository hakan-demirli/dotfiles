{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  name = "git";

  buildInputs = with pkgs; [
    python3
    git
  ];

  dontUnpack = true;
  installPhase = ''
    install -Dm755 ${../scripts/python/git_cached.py} $out/bin/git;
  '';
}
