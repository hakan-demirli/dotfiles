{ pkgs, ... }:
pkgs.stdenv.mkDerivation {
  pname = "ms-fonts";
  version = "2025";

  src = pkgs.fetchFromGitHub {
    owner = "pjobson";
    repo = "Microsoft-365-Fonts";
    rev = "main";
    hash = "sha256-D4wGWex6e9eyyHCfDj/7C8Gfc66jV7NLy3JWLFQVBpg=";
  };

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/fonts/truetype
    mkdir -p $out/share/fonts/opentype
    find . -type f \( -iname "*.ttf" -o -iname "*.ttc" \) -exec install -Dm644 {} $out/share/fonts/truetype/ \;
    find . -type f -iname "*.otf" -exec install -Dm644 {} $out/share/fonts/opentype/ \;
    runHook postInstall
  '';
}
