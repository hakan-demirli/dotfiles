{pkgs}:
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "hyprlock";
  version = "0.1.0-e9a57f0";

  src = pkgs.fetchFromGitHub {
    owner = "hyprwm";
    repo = "hyprlock";
    rev = "1c92c6109c2ef45085e0541c24f6324fd382ac5b";
    hash = "sha256-KtgcrcWu+byG8TNn/HvQvsJ0atZthkAhgPOl/BdFXok=";
  };

  strictDeps = true;

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

  passthru.updateScript = pkgs.nix-update-script {};

  meta = {
    description = "Hyprland's GPU-accelerated screen locking utility";
    homepage = "https://github.com/hyprwm/hyprlock";
    license = pkgs.lib.licenses.bsd3;
    maintainers = with pkgs.lib.maintainers; [eclairevoyant];
    mainProgram = "hyprlock";
    platforms = ["aarch64-linux" "x86_64-linux"];
  };
})
