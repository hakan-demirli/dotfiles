{
  pkgs,
}:
pkgs.stdenv.mkDerivation {
  pname = "gparted";
  version = "${pkgs.gparted.version}-wrapped";

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cat > $out/bin/gparted <<'EOF'
    #!${pkgs.bash}/bin/bash
    pkexec env \
      DISPLAY="$DISPLAY" \
      XAUTHORITY="$XAUTHORITY" \
      WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
      XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      GTK_THEME="$GTK_THEME" \
      GTK2_RC_FILES="$GTK2_RC_FILES" \
      XDG_DATA_DIRS="$XDG_DATA_DIRS" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CURRENT_DESKTOP="$XDG_CURRENT_DESKTOP" \
      DCONF_PROFILE="$DCONF_PROFILE" \
      HOME="$HOME" \
     ${pkgs.gparted}/bin/gparted
    EOF
    chmod +x $out/bin/gparted
  '';
}
