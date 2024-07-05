{
  lib,
  stdenv,
  fetchFromGitHub,
  qtgraphicaleffects,
}:
stdenv.mkDerivation rec {
  pname = "sddm-astronaut-theme.nix";
  version = "";

  src = fetchFromGitHub {
    repo = "sddm-astronaut-theme";
    owner = "Keyitdev";
    rev = "468a100460d5feaa701c2215c737b55789cba0fc";
    sha256 = "sha256-L+5xoyjX3/nqjWtMRlHR/QfAXtnICyGzxesSZexZQMA=";
  };

  dontPatchELF = true;
  dontWrapQtApps = true;
  dontRewriteSymlinks = true;

  propagatedBuildInputs = [ qtgraphicaleffects ];

  installPhase = ''
    mkdir -p $out/share/sddm/themes/astronaut
    mv * $out/share/sddm/themes/astronaut/
  '';

  postFixup = ''
    mkdir -p $out/nix-support
    echo ${qtgraphicaleffects} >> $out/nix-support/propagated-user-env-packages
  '';

  meta = with lib; {
    description = "Sddm theme.";
    homepage = src.meta.homepage;
    license = licenses.gpl3Only;
    platforms = platforms.all;
  };
}
