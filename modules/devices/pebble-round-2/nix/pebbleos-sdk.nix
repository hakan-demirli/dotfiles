{
  pkgs,
  sdkVersion ? "0.1.7",
}:
let
  inherit (pkgs)
    stdenv
    lib
    fetchurl
    autoPatchelfHook
    ;

  bundles = {
    "aarch64-darwin" = {
      osArch = "darwin-aarch64";
      sha256 = "b5c6a75e31efeea276ac26dee928952a293112776f020aaf635e2dd493b063d9";
    };
    "aarch64-linux" = {
      osArch = "linux-aarch64";
      sha256 = "a5844cf5bc6956bdc30c0034b2bd8503c05811f4128c7cbc16e2dde9722bfc9c";
    };
    "x86_64-linux" = {
      osArch = "linux-x86_64";
      sha256 = "e70a384a7575f08e0c6ae98ade3b4684c2e2fdb351e71aa139009a12394fef7e";
    };
  };

  bundle =
    bundles.${stdenv.hostPlatform.system}
      or (throw "pebbleos-sdk: no pre-built SDK bundle for ${stdenv.hostPlatform.system}. Supported: ${toString (lib.attrNames bundles)}");
in
stdenv.mkDerivation {
  pname = "pebbleos-sdk";
  version = sdkVersion;

  src = fetchurl {
    url = "https://github.com/coredevices/PebbleOS-SDK/releases/download/v${sdkVersion}/pebbleos-sdk-${sdkVersion}-${bundle.osArch}.tar.gz";
    inherit (bundle) sha256;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux (
    with pkgs;
    [
      ncurses6
      ncurses5
      libxcrypt-legacy
      xz
      zstd
      glib
      pixman
      zlib
      stdenv.cc.cc.lib
      SDL2
      libpng
      alsa-lib
      libpulseaudio
      systemdLibs
    ]
  );

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    bash install.sh --prefix "$out" --defaults --force
    rm -f "$out"/arm-none-eabi/bin/arm-none-eabi-gdb-py \
          "$out"/arm-none-eabi/bin/arm-none-eabi-gdb-add-index-py
    mkdir -p "$out/bin"
    for d in arm-none-eabi/bin qemu/bin sftool; do
      [ -d "$out/$d" ] || continue
      for f in "$out/$d"/*; do
        [ -f "$f" ] && [ -x "$f" ] && ln -sf "$f" "$out/bin/$(basename "$f")"
      done
    done
    runHook postInstall
  '';

  meta = {
    description = "PebbleOS SDK toolchain (arm-none-eabi + qemu-pebble + sftool)";
    homepage = "https://github.com/coredevices/PebbleOS-SDK";
    license = lib.licenses.unfree;
    platforms = lib.attrNames bundles;
    maintainers = [ ];
  };
}
