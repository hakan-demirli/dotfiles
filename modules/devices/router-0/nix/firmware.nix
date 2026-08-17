{
  pkgs,
  openwrtSource,
  r01-ui,
}:

let
  hostTools = pkgs.runCommand "openwrt-host-tools" { } ''
    mkdir -p $out/bin
    for compiler in ${pkgs.gcc.cc}/bin/*-gnu-gcc*; do
      ln -s ${pkgs.gcc}/bin/gcc $out/bin/$(basename "$compiler")
    done
    for compiler in ${pkgs.gcc.cc}/bin/*-gnu-{g++,c++}*; do
      ln -s ${pkgs.gcc}/bin/g++ $out/bin/$(basename "$compiler")
    done
    ln -sf ${pkgs.gcc.cc}/bin/{,*-gnu-}gcc-{ar,nm,ranlib} $out/bin

    ltoPlugin=$(echo ${pkgs.gcc.cc}/libexec/gcc/*/*/liblto_plugin.so)
    for tool in ar nm ranlib; do
      printf '#!%s\nexec %s/bin/%s --plugin %s "$@"\n' \
        ${pkgs.runtimeShell} ${pkgs.binutils} "$tool" "$ltoPlugin" > $out/bin/$tool
      chmod +x $out/bin/$tool
    done
  '';

  seedConfig = pkgs.writeText "openwrt-seed.config" ''
    CONFIG_TARGET_mediatek=y
    CONFIG_TARGET_mediatek_filogic=y
    CONFIG_TARGET_mediatek_filogic_DEVICE_glinet_gl-be10000=y

    # wpa_supplicant with full EAP (TTLS+MSCHAPv2 for ETH eth network).
    # CONFIG_PACKAGE_wpad-basic-mbedtls is not set
    CONFIG_PACKAGE_wpad-openssl=y

    # Web UI.
    CONFIG_PACKAGE_luci=y
    CONFIG_PACKAGE_luci-ssl=y

    # Tailnet membership. kmod-tun must be baked in: snapshot kmods are keyed
    # by kernel vermagic, and a patched tree's vermagic is never in the feed.
    CONFIG_PACKAGE_tailscale=y
    CONFIG_PACKAGE_kmod-tun=y
    CONFIG_PACKAGE_ca-bundle=y

    # node_exporter-compatible metrics on 9100, scraped over the tailnet.
    # filesystem is a separate collector, and the disk panels/alerts need it.
    CONFIG_PACKAGE_prometheus-node-exporter-lua=y
    CONFIG_PACKAGE_prometheus-node-exporter-lua-filesystem=y
    CONFIG_PACKAGE_prometheus-node-exporter-lua-openwrt=y
    CONFIG_PACKAGE_prometheus-node-exporter-lua-thermal=y
    CONFIG_PACKAGE_prometheus-node-exporter-lua-wifi=y

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

  feedsConfigText = ''
    src-git packages https://git.openwrt.org/feed/packages.git^77879deb5a4b5cc6bf3cc99dac8fd3037a1aa4a2
    src-git luci https://git.openwrt.org/project/luci.git^c26820a2296fa2e1f8bc12c44e82c486c9c837c1
    src-git routing https://git.openwrt.org/feed/routing.git^4b9891b9136259f93294a424507ed24c5e8c1cbd
    src-git telephony https://git.openwrt.org/feed/telephony.git^5d68d53c160a325ea9d03fce393e051573bcc736
    src-git video https://github.com/openwrt/video.git^a951381b6c58b9b1eb087f09c9a20cff4ffe8063
  '';
  feedsConfig = pkgs.writeText "openwrt-feeds.conf" feedsConfigText;
  feedsConfigKey = builtins.hashString "sha256" feedsConfigText;

  sourceKey = builtins.substring 0 32 (builtins.baseNameOf "${openwrtSource}");
  inherit (openwrtSource.passthru) upstreamVersion upstreamDateEpoch;

  buildScript = pkgs.writeShellScript "router-0-firmware-build" ''
    set -euo pipefail

    usage() {
      cat <<'USAGE'
    Build router-0 OpenWrt firmware outside the Nix build sandbox.

    Usage: nix run .#router-0-firmware -- [OPTIONS]

      --output DIR       Copy firmware to DIR (default: ./result-router-0)
      --build-root DIR   Persistent build state (default: $XDG_CACHE_HOME/router-0-firmware)
      --jobs N           Parallel jobs (default: all available CPUs)
      --clean            Remove this source revision's build state first
      --check            Check the runtime build environment and exit
      -h, --help         Show this help

    Environment overrides: ROUTER_0_OUTPUT_DIR, ROUTER_0_BUILD_ROOT, ROUTER_0_JOBS
    USAGE
    }

    die() {
      printf 'router-0-firmware: %s\n' "$*" >&2
      exit 1
    }

    invocation_dir=$PWD
    cache_base="''${XDG_CACHE_HOME:-$HOME/.cache}"
    output_dir="''${ROUTER_0_OUTPUT_DIR:-$invocation_dir/result-router-0}"
    build_root="''${ROUTER_0_BUILD_ROOT:-$cache_base/router-0-firmware}"
    jobs="''${ROUTER_0_JOBS:-$(nproc)}"
    clean=false
    check_only=false

    while (( $# > 0 )); do
      case "$1" in
        --output)
          (( $# >= 2 )) || die "--output requires a directory"
          output_dir=$2
          shift 2
          ;;
        --build-root)
          (( $# >= 2 )) || die "--build-root requires a directory"
          build_root=$2
          shift 2
          ;;
        --jobs)
          (( $# >= 2 )) || die "--jobs requires a number"
          jobs=$2
          shift 2
          ;;
        --clean)
          clean=true
          shift
          ;;
        --check)
          check_only=true
          shift
          ;;
        -h | --help)
          usage
          exit 0
          ;;
        *)
          die "unknown option: $1"
          ;;
      esac
    done

    [[ $jobs =~ ^[1-9][0-9]*$ ]] || die "jobs must be a positive integer: $jobs"
    [[ $output_dir = /* ]] || output_dir="$invocation_dir/$output_dir"
    [[ $build_root = /* ]] || build_root="$invocation_dir/$build_root"

    source_path=${openwrtSource}

    preflight() {
      local tool
      for tool in ar bash bzip2 file flock g++ gcc git make patch perl python3 rsync swig tar unzip wget xz; do
        command -v "$tool" >/dev/null || die "missing build tool: $tool"
      done

      [[ -x "$source_path/scripts/feeds" ]] || die "patched source lost executable modes"
      [[ $(id -u) == 0 ]] || die "FHS environment did not map the build user to root"
      [[ -r /usr/include/iconv.h ]] || die "FHS environment is missing /usr/include/iconv.h"
      [[ -x /lib64/ld-linux-x86-64.so.2 ]] || die "FHS environment is missing the dynamic loader"

      (
        local tmp
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        printf 'int answer(void) { return 42; }\n' > "$tmp/library.c"
        printf 'int answer(void); int main(void) { return answer() == 42 ? 0 : 1; }\n' > "$tmp/main.c"
        gcc -flto -O2 -c "$tmp/library.c" -o "$tmp/library.o"
        ar rcs "$tmp/library.a" "$tmp/library.o"
        gcc -flto -O2 "$tmp/main.c" "$tmp/library.a" -o "$tmp/lto-check"
        "$tmp/lto-check"
      ) || die "host compiler or LTO archive tools are broken"

      wget --spider --quiet --timeout=15 --tries=1 https://downloads.openwrt.org/ \
        || die "cannot reach https://downloads.openwrt.org/"

      echo ">>> runtime environment check passed"
    }

    preflight
    $check_only && exit 0

    mkdir -p "$build_root"
    exec 9>"$build_root/.${sourceKey}.lock"
    echo ">>> waiting for build lock"
    flock 9

    work_dir="$build_root/${sourceKey}"
    $clean && rm -rf "$work_dir"

    marker="$work_dir/.router-0-source"
    if [[ ! -f $marker ]] || [[ $(<"$marker") != "$source_path" ]]; then
      echo ">>> creating persistent build tree: $work_dir"
      tmp_work="$work_dir.tmp.$$"
      rm -rf "$tmp_work"
      mkdir -p "$tmp_work"
      cp -a --no-preserve=ownership "$source_path"/. "$tmp_work"/
      chmod -R u+w "$tmp_work"
      printf '%s\n' "$source_path" > "$tmp_work/.router-0-source"
      rm -rf "$work_dir"
      mv "$tmp_work" "$work_dir"
    else
      echo ">>> reusing persistent build tree: $work_dir"
    fi

    cd "$work_dir"

    printf '%s\n' ${upstreamVersion} > version
    printf '%s\n' ${toString upstreamDateEpoch} > version.date

    feeds_marker="$work_dir/.router-0-feeds"
    if [[ ! -f $feeds_marker ]] || [[ $(<"$feeds_marker") != ${feedsConfigKey} ]]; then
      echo ">>> resetting feeds for pinned revisions"
      rm -rf feeds package/feeds
    fi
    cp ${feedsConfig} feeds.conf

    echo ">>> updating feeds"
    ./scripts/feeds update -a
    printf '%s\n' ${feedsConfigKey} > "$feeds_marker"
    ./scripts/feeds install -a

    echo ">>> configuring firmware"
    cp ${seedConfig} .config
    make defconfig
    install -Dm0755 ${r01-ui}/bin/r01-ui files/usr/bin/r01-ui

    echo ">>> downloading sources"
    make -j"$jobs" download

    echo ">>> building firmware with $jobs jobs"
    make -j"$jobs" V=s world

    firmware_dir=bin/targets/mediatek/filogic
    [[ -d $firmware_dir ]] || die "firmware output directory was not created"
    mapfile -t firmware_images < <(find "$firmware_dir" -maxdepth 1 -type f -name '*sysupgrade.bin' -print)
    if (( ''${#firmware_images[@]} != 1 )); then
      printf 'router-0-firmware: expected one sysupgrade image, found %d:\n' \
        "''${#firmware_images[@]}" >&2
      printf '  %s\n' "''${firmware_images[@]}" >&2
      exit 1
    fi

    mkdir -p "$output_dir"
    install -m0644 "''${firmware_images[0]}" "$output_dir/firmware.bin"
    (cd "$output_dir" && sha256sum firmware.bin > firmware.bin.sha256)

    printf 'Firmware: %s\n' "$output_dir/firmware.bin"
    printf 'Checksum: %s\n' "$output_dir/firmware.bin.sha256"
  '';
in
pkgs.buildFHSEnv {
  pname = "router-0-firmware";
  version = "0.1.0";

  unshareUser = true;
  extraBwrapArgs = [
    "--uid 0"
    "--gid 0"
  ];

  targetPkgs =
    p: with p; [
      bash
      binutils
      bzip2
      cacert
      coreutils
      cpio
      diffutils
      fakeroot
      file
      findutils
      gawk
      gcc
      gettext
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
      zstd
    ];

  extraOutputsToInstall = [
    "dev"
    "static"
  ];

  extraPreBwrapCmds = ''
    unset AS AR CC CFLAGS CPP CPPFLAGS CXX CXXFLAGS LD LDFLAGS NM OBJCOPY OBJDUMP
    unset RANLIB READELF SIZE STRINGS STRIP CMAKE_INCLUDE_PATH CMAKE_PREFIX_PATH
    unset ACLOCAL_PATH PKG_CONFIG_PATH
    while IFS='=' read -r name _; do
      case "$name" in
        NIX_BINTOOLS_WRAPPER_FLAGS_SET_* | NIX_CC_WRAPPER_FLAGS_SET_* | NIX_CFLAGS_* | NIX_CXXSTDLIB_* | NIX_ENFORCE_NO_NATIVE* | NIX_HARDENING_ENABLE | NIX_LDFLAGS*)
          unset "$name"
          ;;
      esac
    done < <(env)
  '';

  profile = ''
    export PATH=${hostTools}/bin:/run/wrappers/bin:/usr/bin:/usr/sbin
    export FORCE_UNSAFE_CONFIGURE=1
  '';

  runScript = "${buildScript}";

  passthru = {
    inherit (openwrtSource.passthru or { }) upstreamRev;
  };

  meta = {
    description = "Runtime OpenWrt firmware builder for GL.iNet GL-BE10000";
    platforms = [ "x86_64-linux" ];
  };
}
