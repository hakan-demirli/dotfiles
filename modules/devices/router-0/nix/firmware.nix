{
  pkgs,
  openwrtSource,
  r01-ui,
}:

let
  fixWrapper = pkgs.runCommand "openwrt-gcc-wrapper" { } ''
    mkdir -p $out/bin
    for i in ${pkgs.gcc.cc}/bin/*-gnu-gcc*; do
      ln -s ${pkgs.gcc}/bin/gcc $out/bin/$(basename "$i")
    done
    for i in ${pkgs.gcc.cc}/bin/*-gnu-{g++,c++}*; do
      ln -s ${pkgs.gcc}/bin/g++ $out/bin/$(basename "$i")
    done
    ln -sf ${pkgs.gcc.cc}/bin/{,*-gnu-}gcc-{ar,nm,ranlib} $out/bin
  '';

  seedConfig = pkgs.writeText "openwrt-seed.config" ''
    CONFIG_TARGET_mediatek=y
    CONFIG_TARGET_mediatek_filogic=y
    CONFIG_TARGET_mediatek_filogic_DEVICE_glinet_gl-be10000=y

    # wpa_supplicant with full EAP (TTLS+MSCHAPv2 for ETH eth network).
    CONFIG_PACKAGE_wpad-openssl=y

    # Web UI.
    CONFIG_PACKAGE_luci=y
    CONFIG_PACKAGE_luci-ssl=y

    # Useful tools.
    CONFIG_PACKAGE_diffutils=y
    CONFIG_PACKAGE_tcpdump-mini=y
    CONFIG_PACKAGE_ethtool=y
    CONFIG_PACKAGE_iw-full=y
    CONFIG_PACKAGE_ip-full=y

    # Recovery initramfs (PR define references it).
    CONFIG_TARGET_ROOTFS_INITRAMFS=y

    # LCD: DRM tiny st7789p3 driver + pwm-backlight.
    CONFIG_DISPLAY_SUPPORT=y
    CONFIG_PACKAGE_kmod-backlight=y
    CONFIG_PACKAGE_kmod-backlight-pwm=y
    CONFIG_PACKAGE_kmod-drm=y
    CONFIG_PACKAGE_kmod-drm-st7789p3=y
    CONFIG_PACKAGE_kmod-fb=y

    # Touch input (DTS + in-tree kernel patch supply the driver).
    CONFIG_PACKAGE_kmod-input-evdev=y

    # Roaming STA: travelmate scans configured uplinks and connects
    # to the best one in range, handles captive portals, fails over
    # on signal loss.
    CONFIG_PACKAGE_travelmate=y
    CONFIG_PACKAGE_iwinfo=y
    CONFIG_PACKAGE_uclient-fetch=y
  '';

  buildPkgs = with pkgs; [
    bash
    binutils
    bzip2
    coreutils
    diffutils
    fakeroot
    file
    findutils
    fixWrapper
    gawk
    gcc
    gettext
    glibc
    glibc.dev
    glibc.static
    git
    gnumake
    gnused
    gnutar
    gzip
    ncurses
    openssl
    patch
    perl
    pkg-config
    (python3.withPackages (ps: [ ps.setuptools ]))
    rsync
    subversion
    swig
    unzip
    util-linux
    wget
    which
    xz
    zlib
    zlib.static
    zstd
  ];
in
pkgs.stdenv.mkDerivation {
  pname = "openwrt-be10000-firmware";
  version = "0.1.0";

  src = openwrtSource;

  __noChroot = true;

  nativeBuildInputs = buildPkgs;

  hardeningDisable = [ "all" ];

  unpackPhase = ''
    runHook preUnpack
    # We can't build inside $src (read-only nix store). Materialise a
    # writable copy in $TMPDIR and operate from there.
    cp -r --no-preserve=mode,ownership ${openwrtSource} ./openwrt
    chmod -R u+w ./openwrt
    sourceRoot=$(pwd)/openwrt
    runHook postUnpack
  '';

  configurePhase = ''
    runHook preConfigure
    cd $sourceRoot

    # Make `gcc`/`g++` resolve to host gcc even for un-prefixed names
    # openwrt's bootstrap expects.
    export PATH=${fixWrapper}/bin:$PATH

    echo ">>> updating feeds"
    ./scripts/feeds update -a
    ./scripts/feeds install -a

    echo ">>> seeding .config"
    cp ${seedConfig} .config

    echo ">>> make defconfig"
    make defconfig

    # Drop the cross-built r01-ui into the overlay where `make world`
    # will pick it up.
    install -Dm0755 ${r01-ui}/bin/r01-ui files/usr/bin/r01-ui

    runHook postConfigure
  '';

  buildPhase = ''
        runHook preBuild
        cd $sourceRoot

        echo ">>> preflight: network reachability + writable /tmp"
        if ! wget --spider --quiet --timeout=15 --tries=1 https://downloads.openwrt.org/ 2>&1; then
          cat >&2 <<PREFLIGHT_FAIL

    ======================================================================
      router-0-firmware preflight FAILED
    ======================================================================

      This derivation is __noChroot = true and needs unrestricted network
      + writable host /tmp during \`make world\`. The preflight check for
      network reachability to https://downloads.openwrt.org/ failed.

      Most likely causes, in order of probability:

      (a) nix.conf sandbox is not relaxed. Options:
          - Transient (this invocation only):
              nix build --option sandbox relaxed .#router-0-firmware
          - Per-user, persistent:
              mkdir -p ~/.config/nix
              echo 'sandbox = relaxed' >> ~/.config/nix/nix.conf
              sudo systemctl restart nix-daemon
          - System-wide, persistent (NixOS):
              nix.settings.sandbox = "relaxed";   # in your host module
              sudo nixos-rebuild switch
          - System-wide, persistent (non-NixOS):
              echo 'sandbox = relaxed' | sudo tee -a /etc/nix/nix.conf
              sudo systemctl restart nix-daemon

      (b) You are offline / behind a corporate firewall / DNS is broken.
          Verify by hand:
              wget --spider https://downloads.openwrt.org/

      (c) The openwrt mirror is temporarily unreachable. Retry in a few
          minutes.

      Build with: nix build --option sandbox relaxed .#router-0-firmware
    ======================================================================

    PREFLIGHT_FAIL
          exit 1
        fi

        if ! touch /tmp/router-0-firmware-preflight-can-write 2>/dev/null; then
          echo "preflight FAILED: /tmp is not writable inside the builder" >&2
          echo "  This means __noChroot is not being honoured." >&2
          echo "  Set sandbox = relaxed or pass --option sandbox relaxed." >&2
          exit 1
        fi
        rm -f /tmp/router-0-firmware-preflight-can-write

        echo ">>> downloading sources (~1 GB, --noChroot grants network)"
        make -j$NIX_BUILD_CORES download

        echo ">>> make world (under unshare --map-root-user)"
        unshare --user --map-root-user --keep-caps -- \
          make -j$NIX_BUILD_CORES V=s world

        runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp bin/targets/mediatek/filogic/*sysupgrade.bin $out/firmware.bin
    # Keep sha256sums for traceability.
    (cd $out && sha256sum firmware.bin > firmware.bin.sha256)
    runHook postInstall
  '';

  passthru = {
    inherit (openwrtSource.passthru or { }) upstreamRev;
  };

  meta = {
    description = "OpenWrt sysupgrade image for GL.iNet GL-BE10000";
    platforms = [ "x86_64-linux" ];
  };
}
