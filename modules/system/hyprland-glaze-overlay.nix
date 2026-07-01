_final: prev: {
  hyprland = prev.hyprland.overrideAttrs (oldAttrs: {
    # https://github.com/NixOS/nixpkgs/pull/549253
    postPatch = ''
      substituteInPlace CMakeLists.txt start/CMakeLists.txt hyprpm/CMakeLists.txt \
        --replace-fail "glaze 7...<8" "glaze"
    ''
    + (oldAttrs.postPatch or "");
  });
}
