{pkgs}:
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "hyprlock";
  version = "0.3.0-6fa65e1";

  src = pkgs.fetchFromGitHub {
    owner = "hyprwm";
    repo = "hyprlock";
    rev = "415262065fff0a04b229cd00165f346a86a0a73a";
    hash = "sha256-jla5Wo0Qt3NEnD0OjNj85BGw0pR4Zlz5uy8AqHH7tuE=";
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

    pkgs.libjpeg
    pkgs.libwebp
    pkgs.file
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
