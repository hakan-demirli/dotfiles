{pkgs}:
pkgs.stdenv.mkDerivation (finalAttrs: {
  pname = "hyprlock";
  version = "0.1.0-e9a57f0";

  src = pkgs.fetchFromGitHub {
    owner = "hyprwm";
    repo = "hyprlock";
    rev = "f3a41161eca06074de40c60991f569f1db77182a";
    hash = "sha256-x1FWQbRxXHZwTVSNq649Qj1JmkHppiKq+X+cjPyt2Wg=";
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
