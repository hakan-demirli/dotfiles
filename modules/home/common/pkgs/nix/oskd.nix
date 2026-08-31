{
  pkgs,
}:
let
  source = ./src/oskd.c;
  protocol = "${pkgs.wlroots.src}/protocol/virtual-keyboard-unstable-v1.xml";
in
pkgs.stdenv.mkDerivation {
  pname = "oskd";
  version = "0.1";
  dontUnpack = true;
  dontConfigure = true;
  nativeBuildInputs = [
    pkgs.pkg-config
    pkgs.wayland-scanner
  ];
  buildInputs = [
    pkgs.libxkbcommon
    pkgs.wayland
  ];
  buildPhase = ''
    runHook preBuild
    wayland-scanner client-header ${protocol} virtual-keyboard-unstable-v1-client-protocol.h
    wayland-scanner private-code ${protocol} virtual-keyboard-unstable-v1-protocol.c
    $CC -O2 -Wall -Wextra -Werror -I. -o oskd \
      ${source} virtual-keyboard-unstable-v1-protocol.c \
      $(pkg-config --cflags --libs wayland-client xkbcommon)
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 oskd $out/bin/oskd
    runHook postInstall
  '';
  meta = {
    mainProgram = "oskd";
    platforms = pkgs.lib.platforms.linux;
  };
}
