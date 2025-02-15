{ pkgs, lib }:
pkgs.stdenv.mkDerivation {
  pname = "xdg-desktop-portal-termfilechooser";
  version = "0.1";
  src = pkgs.fetchFromGitHub {
    owner = "boydaihungst";
    repo = "xdg-desktop-portal-termfilechooser";
    # ref = "fix-for-lf";
    rev = "6acc64bbc8f309f92a527006203e2a484b6a109e";
    sha256 = "sha256-oKd128CC1NVP3TTe3S0gPzFdQ+f12dGNpBxvOAuC4Hs=";
  };

  strictDeps = true;

  depsBuildBuild = [ pkgs.pkg-config ];

  nativeBuildInputs = with pkgs; [
    meson
    ninja
    pkg-config
    scdoc
    wayland-scanner
    makeWrapper
  ];

  buildInputs = with pkgs; [
    xdg-desktop-portal
    inih
    libdrm
    mesa
    systemd
    wayland
    wayland-protocols
  ];

  patches = [ ./termfilechooser.patch ];

  patchPhase = ''
    # sed -i '/pantheon/ s/$/;Hyprland/' termfilechooser.portal

    substituteInPlace contrib/lf-wrapper.sh \
      --replace "#!/bin/sh" "#!/usr/bin/env bash" \
      --replace /usr/bin/lf ${pkgs.lf}/bin/lf \
      --replace /usr/bin/kitty ${pkgs.kitty}/bin/kitty \
      --replace /usr/bin/rm ${pkgs.coreutils}/bin/rm

    substituteInPlace contrib/config \
      --replace /home/boydaihungst/.config/xdg-desktop-portal-termfilechooser/vifm-wrapper.sh ${placeholder "out"}/share/xdg-desktop-portal-termfilechooser/lf-wrapper.sh \
      --replace /home/boydaihungst/Downloads /tmp


    echo "
      install_data(
          'contrib/lf-wrapper.sh',
          install_dir: join_paths(get_option('datadir'), 'xdg-desktop-portal-termfilechooser'),
      )
      install_data(
          'contrib/fzf-wrapper.sh',
          install_dir: join_paths(get_option('datadir'), 'xdg-desktop-portal-termfilechooser'),
      )" >> meson.build
  '';

  postPatch = ''
    # Allow using lf out of the box without any configuration.
    substituteInPlace src/core/config.c \
      --replace-fail '"/usr/share/xdg-desktop-portal-termfilechooser/ranger-wrapper.sh"' '"${placeholder "out"}/share/xdg-desktop-portal-termfilechooser/lf-wrapper.sh"'
  '';

  mesonFlags = [
    (lib.mesonOption "sysconfdir" "/etc")
    (lib.mesonEnable "systemd" true)
    (lib.mesonEnable "man-pages" true)
    (lib.mesonOption "sd-bus-provider" "libsystemd")
  ];

  mesonBuildType = "release";
}
