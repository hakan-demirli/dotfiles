{
  pkgs,
  lib,
}:
pkgs.stdenv.mkDerivation {
  pname = "xdg-desktop-portal-termfilechooser";
  version = "0.1";
  src = pkgs.fetchFromGitHub {
    owner = "boydaihungst";
    repo = "xdg-desktop-portal-termfilechooser";
    # ref = "fix-for-lf";
    rev = "6acc64bbc8f309f92a527006203e2a484b6a109e";
    sha256 = "LUO5ej0c/bdSxZU4RIw3nzPqQmWCGWhmOTQC5RVz5n4=";
  };

  nativeBuildInputs = with pkgs; [
    meson
    ninja
    scdoc
    pkgconf
  ];

  buildInputs = with pkgs; [
    xdg-desktop-portal
    inih
    systemd
  ];

  # Add hyprland support
  patchPhase = ''
    sed -i '/pantheon/ s/$/;Hyprland/' termfilechooser.portal

    substituteInPlace contrib/lf-wrapper.sh \
      --replace /usr/bin/ranger ${pkgs.lf}/bin/lf \
      --replace /usr/bin/kitty ${pkgs.kitty}/bin/kitty \
      --replace '"$termcmd"' '$termcmd' \
      --replace 'rm "' '${pkgs.coreutils}/bin/rm "'
  '';

  mesonFlags = [
    (lib.mesonEnable "systemd" true)
    (lib.mesonEnable "man-pages" true)
    (lib.mesonOption "sd-bus-provider" "libsystemd")
  ];

  mesonBuildType = "release";
}
