{pkgs, ...}:
pkgs.stdenv.mkDerivation {
  name = "gtk_indicator";

  nativeBuildInputs = with pkgs; [
    wrapGAppsHook
    gobject-introspection
    libappindicator
  ];
  propagatedBuildInputs = [
    pkgs.gtk4-layer-shell
    pkgs.gtk4

    pkgs.gvfs

    (pkgs.python3.withPackages (pythonPackages:
      with pythonPackages; [
        pygobject3
      ]))
  ];
  dontUnpack = true;

  src = ../scripts/python/gtk_indicator;

  installPhase = ''
    mkdir -p $out/bin
    cp -r $src/* $out/
    makeWrapper $out/gtk_indicator.py $out/bin/gtk_indicator \
      --set LD_PRELOAD ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
    makeWrapper $out/gtk_indicator_client.py $out/bin/gtk_indicator_client \
      --set LD_PRELOAD ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
    makeWrapper $out/gtk_indicator_client_volume.py $out/bin/gtk_indicator_client_volume \
      --set LD_PRELOAD ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
    makeWrapper $out/gtk_indicator_client_mic.py $out/bin/gtk_indicator_client_mic \
      --set LD_PRELOAD ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
    makeWrapper $out/gtk_indicator_client_brightness.py $out/bin/gtk_indicator_client_brightness \
      --set LD_PRELOAD ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
    chmod +x $out/bin/gtk_indicator
    chmod +x $out/bin/gtk_indicator_client
    chmod +x $out/bin/gtk_indicator_client_volume
    chmod +x $out/bin/gtk_indicator_client_mic
    chmod +x $out/bin/gtk_indicator_client_brightness
  '';
}
