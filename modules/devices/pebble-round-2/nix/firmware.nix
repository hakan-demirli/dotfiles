{
  pkgs,
  pebbleosSource,
  pebbleosSdk,
  board ? "getafix@dvt2",
  variant ? "normal",
  releaseBuild ? false,
  enableModdableXs ? false,
}:
let
  inherit (pkgs) lib;

  boardSlug = builtins.replaceStrings [ "@" ] [ "_" ] board;
  bundlePrefix = if variant == "prf" then "recovery" else variant;

  pythonEnv = import ./python-env.nix { inherit pkgs; };

  clangBinsOnly = pkgs.runCommand "pebble-clang-bins" { } ''
    mkdir -p $out/bin
    ln -sf ${pkgs.clang}/bin/clang $out/bin/clang
    ln -sf ${pkgs.clang}/bin/clang++ $out/bin/clang++
  '';
in
pkgs.stdenv.mkDerivation {
  pname = "pebble-round-2-firmware";
  version = "${pebbleosSource.passthru.upstreamTag or "dev"}-${board}";

  src = pebbleosSource;

  nativeBuildInputs = with pkgs; [
    pythonEnv
    pebbleosSdk
    pkg-config
    git
    gcc
    clangBinsOnly
    binutils
    dash
    gettext
    librsvg
    nodejs
    protobuf
    meson
    ninja
    which
    gnumake
  ];

  buildInputs = with pkgs; [
    glib
    gtk3
  ];

  dontConfigure = true;

  hardeningDisable = [ "all" ];

  unpackPhase = ''
    runHook preUnpack
    # cp -r without --no-preserve=mode keeps the 0555 exec bit on ./waf
    # and ./pbl from the fixed-output source. Only ownership is stripped.
    # Then chmod -R u+w flips read-only bits so waf can write into
    # build/ and the source tree.
    cp -r --no-preserve=ownership ${pebbleosSource} ./pebbleos
    chmod -R u+w ./pebbleos
    sourceRoot=$(pwd)/pebbleos
    runHook postUnpack
  '';

  postPatch = ''
    patchShebangs waf pbl tools/ third_party/moddable/moddable/tools/ \
      third_party/moddable/moddable/xs/tools/ \
      third_party/moddable/moddable/build/tools/ 2>/dev/null || true
    # Fallback: any script with a bad shebang anywhere in the tree.
    patchShebangs .
  '';

  buildPhase = ''
    runHook preBuild
    cd $sourceRoot

    # HOME needs to be writable for any tool that touches $HOME/.cache.
    export HOME="$TMPDIR/pebble-home"
    mkdir -p "$HOME"
    export XDG_CACHE_HOME="$HOME/.cache"

    # Match the upstream env.sh PATH order: SDK's arm-none-eabi/bin ahead
    # of everything so waf's `find_program(['gcc'])` resolves to
    # arm-none-eabi-gcc (14.2.1), not the nixpkgs host gcc (15.2.0)
    # which trips pebble_arm_gcc.py's toolchain version check.
    export PATH="${pebbleosSdk}/arm-none-eabi/bin:${pebbleosSdk}/qemu/bin:${pebbleosSdk}/sftool:$PATH"

    # nix stdenv exports CC/CXX/AR/etc. by default (== host gcc). Waf's
    # `find_program(..., var='CC')` in `waflib/Configure.py` checks
    # `os.environ['CC']` BEFORE `conf.env.CC`, which means the
    # stdenv-injected CC=gcc wins over pebble_arm_gcc.py's
    # `conf.env.CC = "arm-none-eabi-gcc"`. Same story for the unit-test
    # env's `find_program('clang', var='CC')` because it also returns gcc.
    # Unset the vars so waf falls through to conf.env / PATH search.
    unset CC CXX AR AS LD RANLIB NM STRIP OBJDUMP OBJCOPY READELF SIZE HOSTCC HOSTCXX

    # pebble_arm_gcc.py's toolchain version check reads `gcc --version`
    # (unprefixed) from PATH, not `arm-none-eabi-gcc`. On our nixpkgs
    # host that's 15.2.0 which trips the 13.0..14.2.1 restriction.
    # Actual cross-compile still goes through arm-none-eabi-gcc-14.2.1
    # from the SDK. Bypass the version guard.
    echo ">>> waf configure --board ${board}${lib.optionalString releaseBuild " -DCONFIG_RELEASE=y"}${
      lib.optionalString (!enableModdableXs) " -DCONFIG_MODDABLE_XS=n"
    }"
    ./waf configure \
      --board=${board} \
      --variant=${variant} \
      --relax_toolchain_restrictions \
      ${lib.optionalString releaseBuild "-DCONFIG_RELEASE=y"} \
      ${lib.optionalString (!enableModdableXs) "-DCONFIG_MODDABLE_XS=n"}

    # tools/waf/gitinfo.py calls `git rev-parse --short HEAD` and
    # `git describe --dirty` to stamp the firmware image. Our source
    # is a fixed-output fetchFromGitHub without a .git dir, so those
    # commands fail with exit 128. Bootstrap a minimal repo state so
    # the version stamp resolves. The tag comes from the upstream
    # rev pin in nix/pebbleos-source.nix.
    if [ ! -d .git ]; then
      export GIT_AUTHOR_NAME=nix
      export GIT_AUTHOR_EMAIL=nix@localhost
      export GIT_COMMITTER_NAME=nix
      export GIT_COMMITTER_EMAIL=nix@localhost
      git init -q -b main .
      # Stage nothing (waf writes into the tree during build. Committing
      # everything now would make it 'clean' for a moment and then
      # 'dirty' after the first waf write, tripping `git describe --dirty`
      # regex parsing in gitinfo.py). An empty-tree commit is enough.
      git commit -q --allow-empty -m "nix pin: ${pebbleosSource.passthru.upstreamRev}"
      # Annotated tag: `git describe` (used by gitinfo.py) ignores
      # lightweight tags unless invoked with --tags. Since we can't
      # patch waf's gitinfo.py, use an annotated tag. Environment variables set
      # the committer/tagger identity.
      git tag -a "${pebbleosSource.passthru.upstreamTag}" \
              -m "nix pin: upstream release"
    fi


    echo ">>> waf build"
    ./waf build

    echo ">>> waf bundle"
    ./waf bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out

    shopt -s nullglob
    pbz_files=( build/${bundlePrefix}_${boardSlug}_*.pbz )
    if [ ''${#pbz_files[@]} -eq 0 ]; then
      echo "ERROR: no .pbz bundle emitted. Expected build/${bundlePrefix}_${boardSlug}_*.pbz" >&2
      echo "Build tree state:" >&2
      ls -la build/ >&2 || true
      exit 1
    fi

    for f in "''${pbz_files[@]}"; do
      cp "$f" "$out/$(basename "$f")"
    done

    # Symlink a stable name for convenience.
    ln -sf "$(basename "''${pbz_files[0]}")" "$out/firmware.pbz"

    # Ship the pebbleos.bin ELF-ish blob too if present (useful for gdb).
    if [ -f build/pebbleos.bin ]; then
      cp build/pebbleos.bin $out/pebbleos.bin
    fi

    (cd $out && sha256sum firmware.pbz > firmware.pbz.sha256)
    runHook postInstall
  '';

  passthru = {
    inherit board variant releaseBuild;
    inherit (pebbleosSource.passthru) upstreamRev upstreamTag;
    sdkVersion = pebbleosSdk.version;
  };

  meta = {
    description = "PebbleOS firmware bundle for Pebble Round 2 (getafix@dvt2)";
    homepage = "https://github.com/coredevices/PebbleOS";
    license = lib.licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };
}
