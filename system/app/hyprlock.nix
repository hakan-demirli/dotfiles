{pkgs}:
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "hyprlock";
  version = "0.1.0-e9a57f0";

  src = pkgs.fetchFromGitHub {
    owner = "hyprwm";
    repo = "hyprlock";
    rev = "160fe3553fae1c2fb5f3480bada708bff9405e0b";
    hash = "sha256-njx7ZjsIaOo+l9vF2FNtF1nvckHK/8gcqpN3EYitIoY=";
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
