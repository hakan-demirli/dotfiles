{
  pkgs,
  src,
  appSdk,
  pebbleosSdk,
}:
let
  inherit (pkgs) lib;

  pythonEnv = import ./python-env.nix { inherit pkgs; };

  info = lib.importJSON "${src}/package.json";
in
pkgs.stdenv.mkDerivation {
  pname = "pebble-round-2-${info.name}";
  inherit (info) version;

  inherit src;

  nativeBuildInputs = [
    pythonEnv
    pebbleosSdk
  ];

  dontConfigure = true;
  hardeningDisable = [ "all" ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export PATH="${pebbleosSdk}/arm-none-eabi/bin:$PATH"
    unset CC CXX AR AS LD RANLIB NM STRIP OBJDUMP OBJCOPY READELF SIZE HOSTCC HOSTCXX

    cp -r --no-preserve=ownership ${appSdk} "$TMPDIR/sdk"
    chmod -R u+w "$TMPDIR/sdk"

    "$TMPDIR/sdk/waf" configure
    "$TMPDIR/sdk/waf" build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    shopt -s nullglob
    bundles=(build/*.pbw)
    if [ ''${#bundles[@]} -ne 1 ]; then
      echo "ERROR: expected exactly one .pbw, got: ''${bundles[*]:-none}" >&2
      exit 1
    fi
    install -Dm644 "''${bundles[0]}" "$out/${info.name}.pbw"
    runHook postInstall
  '';

  passthru.sdk = appSdk;

  meta = {
    description = "${info.pebble.displayName} watchface for Pebble Round 2";
    platforms = lib.platforms.linux;
  };
}
