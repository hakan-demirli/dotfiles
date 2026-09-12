{
  pkgs,
  pebbleosSource,
  pebbleosSdk,
  board ? "getafix@dvt2",
  platform ? "gabbro",
}:
let
  inherit (pkgs) lib;

  pythonEnv = import ./python-env.nix { inherit pkgs; };

  clangBinsOnly = pkgs.runCommand "pebble-clang-bins" { } ''
    mkdir -p $out/bin
    ln -sf ${pkgs.clang}/bin/clang $out/bin/clang
    ln -sf ${pkgs.clang}/bin/clang++ $out/bin/clang++
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "pebble-round-2-app-sdk";
  version = pebbleosSource.passthru.upstreamTag;

  src = pebbleosSource;

  nativeBuildInputs = with pkgs; [
    pythonEnv
    pebbleosSdk
    clangBinsOnly
    binutils
    dash
    gcc
    gettext
    git
    gnumake
    librsvg
    nodejs
    pkg-config
    protobuf
    which
  ];

  dontConfigure = true;
  hardeningDisable = [ "all" ];

  unpackPhase = ''
    runHook preUnpack
    cp -r --no-preserve=ownership ${pebbleosSource} ./pebbleos
    chmod -R u+w ./pebbleos
    sourceRoot=$(pwd)/pebbleos
    runHook postUnpack
  '';

  postPatch = ''
    patchShebangs .
  '';

  buildPhase = ''
    runHook preBuild
    cd $sourceRoot

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export XDG_CACHE_HOME="$HOME/.cache"

    export PATH="${pebbleosSdk}/arm-none-eabi/bin:$PATH"
    unset CC CXX AR AS LD RANLIB NM STRIP OBJDUMP OBJCOPY READELF SIZE HOSTCC HOSTCXX

    export GIT_AUTHOR_NAME=nix GIT_AUTHOR_EMAIL=nix@localhost
    export GIT_COMMITTER_NAME=nix GIT_COMMITTER_EMAIL=nix@localhost
    git init -q -b main .
    git commit -q --allow-empty -m "nix pin: ${pebbleosSource.passthru.upstreamRev}"
    git tag -a "${pebbleosSource.passthru.upstreamTag}" -m "nix pin"

    ./waf configure \
      --board=${board} \
      --variant=normal \
      --relax_toolchain_restrictions \
      -DCONFIG_MODDABLE_XS=n
    ./waf build --onlysdk

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    if [ ! -f build/sdk/${platform}/lib/libpebble.a ]; then
      echo "ERROR: SDK generation produced no libpebble.a" >&2
      ls -la build/sdk >&2 || true
      exit 1
    fi
    cp -r build/sdk $out
    runHook postInstall
  '';

  passthru = { inherit board platform; };

  meta = {
    description = "Pebble app SDK (pebble.h + libpebble.a) for the ${platform} platform";
    homepage = "https://github.com/coredevices/PebbleOS";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
  };
}
