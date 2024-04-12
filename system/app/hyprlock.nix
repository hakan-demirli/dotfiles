{pkgs}:
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "hyprlock";
  version = "0.3.0-6fa65e1";

  src = pkgs.fetchFromGitHub {
    owner = "hyprwm";
    repo = "hyprlock";
    rev = "6fa65e1172d633e61ed957a49e7cf96010432623";
    hash = "sha256-7ISUD6Z8FivTw/Db8tGJdiJeqpvJs7CSCwadopb1oro=";
  };

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.pkg-config
  ];

  buildInputs = [
    pkgs.cairo
    pkgs.hyprlang
    pkgs.libdrm
    pkgs.libGL
    pkgs.libxkbcommon
    pkgs.mesa
    pkgs.pam
    pkgs.pango
    pkgs.wayland
    pkgs.wayland-protocols
  ];

  meta = {
    description = "Hyprland's GPU-accelerated screen locking utility";
    homepage = "https://github.com/hyprwm/hyprlock";
    license = pkgs.lib.licenses.bsd3;
    maintainers = with pkgs.lib.maintainers; [eclairevoyant];
    mainProgram = "hyprlock";
    platforms = ["aarch64-linux" "x86_64-linux"];
  };
})
