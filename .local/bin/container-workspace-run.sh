#!/usr/bin/env bash

CONTAINER_RUNTIME="docker"
TOTAL_TMPFS_SIZE="100g"
HOST_HOME="$HOME"

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Launches the ephemeral, high-performance Nix development environment."
  echo ""
  echo "Options:"
  echo "  -r, --runtime <name>         Container runtime to use (e.g., docker, podman)."
  echo "                               Default: ${CONTAINER_RUNTIME}"
  echo "  -s, --size <size>            Total size for the shared in-memory tmpfs (e.g., 120g)."
  echo "                               Default: ${TOTAL_TMPFS_SIZE}"
  echo "  -H, --host-home <path>       Path on the host for persistent storage."
  echo "                               Default: ${HOST_HOME}"
  echo "  -h, --help                   Display this help message and exit."
}

SHORT_OPTS="r:s:H:h"
LONG_OPTS="runtime:,size:,host-home:,help"

if ! PARSED=$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@"); then
  exit 1
fi

eval set -- "$PARSED"

while true; do
  case "$1" in
    -r | --runtime)
      CONTAINER_RUNTIME="$2"
      shift 2
      ;;
    -s | --size)
      TOTAL_TMPFS_SIZE="$2"
      shift 2
      ;;
    -H | --host-home)
      HOST_HOME="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Programming error"
      exit 3
      ;;
  esac
done

echo "--- Launching Environment ---"
echo "Container Runtime:   ${CONTAINER_RUNTIME}"
echo "Shared Tmpfs Size:   ${TOTAL_TMPFS_SIZE}"
echo "Persistent Home:     ${HOST_HOME}"
echo "---------------------------"

# shellcheck disable=SC2016
$CONTAINER_RUNTIME run --rm -it \
  --cap-add SYS_ADMIN \
  --tmpfs /mem:rw,size="$TOTAL_TMPFS_SIZE",exec \
  -v "$HOST_HOME":/persistent:rw,z \
  -v "$HOST_HOME"/.local/share/repx-store:/mnt/demirlie/.local/share/repx-store:z \
  -v "$HOST_HOME"/Desktop:/host-desktop:z \
  -v "$HOST_HOME"/Downloads:/host-downloads:z \
  docker.io/nixos/nix \
  nix-shell -p zstd gnutar util-linux coreutils rsync nix tailscale --run '
    set -e

    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export TERM="${TERM:-xterm-256color}"
    export TZ="${TZ:-UTC}"

    mkdir -p /mem/nix /mem/workspace /mem/tmp

    rsync -a /tmp/ /mem/tmp/
    mount --bind /mem/tmp /tmp

    mkdir -p /workspace
    mount --bind /mem/workspace /workspace

    echo "Preparing in-memory Nix environment..."

    echo "Populating in-memory store from archive..."
    # cp /persistent/nix.tar.zst /tmp/
    # tar -I "zstd -d -T0" -xf /tmp/nix.tar.zst -C /mem/nix
    # rm /tmp/nix.tar.zst
    tar -I "zstd -d -T0" -xf /persistent/nix.tar.zst -C /mem/nix

    echo "Syncing bootstrap tools to in-memory store..."
    rsync -a /nix/store/ /mem/nix/store/

    echo "Activating in-memory Nix environment..."
    mount --bind /mem/nix /nix

    echo "Setting up workspace..."
    # cp /persistent/workspace.tar.zst /tmp/
    # tar -I "zstd -d -T0" -xf /tmp/workspace.tar.zst -C /workspace
    # rm /tmp/workspace.tar.zst
    tar -I "zstd -d -T0" -xf /persistent/workspace.tar.zst -C /workspace

    echo "Setting up Tailscale state..."
    mkdir -p /mem/tailscale
    tar -I "zstd -d -T0" -xf /persistent/tailscale.tar.zst -C /mem/tailscale
    mkdir -p /var/lib/tailscale
    mount --bind /mem/tailscale /var/lib/tailscale

    mkdir -p /root/.config
    mkdir -p /root/.local/bin
    mkdir -p /root/.local/share

    ln -sf /workspace/Desktop /root/Desktop
    ln -sf /workspace/.bashrc /root/.bashrc
    ln -sf /workspace/.bash_profile /root/.bash_profile
    ln -sf /workspace/Desktop/dotfiles/.config/* /root/.config
    ln -sf /workspace/Desktop/dotfiles/.local/bin/* /root/.local/bin

    echo "Starting Tailscale daemon..."
    mkdir -p /var/log
    tailscaled --state=/var/lib/tailscale/tailscaled.state --tun=userspace-networking > /var/log/tailscaled.log 2>&1 &

    echo "Workspace loaded. Executing into main Nix environment..."
    cd /root/Desktop/dotfiles
    rm -rf /root/.nix-profile
    nix profile install .#barebone --extra-experimental-features "nix-command flakes"

    if [[ -f /root/.nix-profile/lib/locale/locale-archive ]]; then
        export LOCALE_ARCHIVE=/root/.nix-profile/lib/locale/locale-archive
    fi
    export TERMINFO_DIRS="/root/.nix-profile/share/terminfo${TERMINFO_DIRS:+:$TERMINFO_DIRS}"
    export PATH="/root/.nix-profile/bin:$PATH"

    exec bash -i
  '
