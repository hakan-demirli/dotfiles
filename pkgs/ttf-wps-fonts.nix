{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "ttf-wps-fonts";
  version = "0-unstable-2025-02-04";

  src = pkgs.fetchFromGitHub {
    owner = "dv-anomaly";
    repo = "ttf-wps-fonts";
    rev = "8c980c24289cb08e03f72915970ce1bd6767e45a";
    sha256 = "sha256-x+grMnpEGLkrGVud0XXE8Wh6KT5DoqE6OHR+TS6TagI=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    find . -type f \( -iname "*.ttf" -o -iname "*.ttc" \) -exec install -Dm644 {} $out/share/fonts/truetype/ \;
    runHook postInstall
  '';
}
