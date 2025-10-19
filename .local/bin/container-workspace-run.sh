#!/usr/bin/env bash

CONTAINER_RUNTIME="docker"
NIX_TMPFS_SIZE="50g"
WORKSPACE_TMPFS_SIZE="15g"
HOST_HOME="$HOME"

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Launches the ephemeral, high-performance Nix development environment."
  echo ""
  echo "Options:"
  echo "  -r, --runtime <name>         Container runtime to use (e.g., docker, podman)."
  echo "                               Default: ${CONTAINER_RUNTIME}"
  echo "  -n, --nix-size <size>        Size for the /nix tmpfs (e.g., 50g, 100g)."
  echo "                               Default: ${NIX_TMPFS_SIZE}"
  echo "  -w, --workspace-size <size>  Size for the /workspace tmpfs (e.g., 15g, 20g)."
  echo "                               Default: ${WORKSPACE_TMPFS_SIZE}"
  echo "  -H, --host-home <path>       Path on the host for persistent storage."
  echo "                               Default: ${HOST_HOME}"
  echo "  -h, --help                   Display this help message and exit."
}

SHORT_OPTS="r:n:w:H:h"
LONG_OPTS="runtime:,nix-size:,workspace-size:,host-home:,help"

PARSED=$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")
if [[ $? -ne 0 ]]; then
  exit 1
fi

eval set -- "$PARSED"

while true; do
  case "$1" in
    -r|--runtime)
      CONTAINER_RUNTIME="$2"
      shift 2
      ;;
    -n|--nix-size)
      NIX_TMPFS_SIZE="$2"
      shift 2
      ;;
    -w|--workspace-size)
      WORKSPACE_TMPFS_SIZE="$2"
      shift 2
      ;;
    -H|--host-home)
      HOST_HOME="$2"
      shift 2
      ;;
    -h|--help)
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
echo "Container Runtime: ${CONTAINER_RUNTIME}"
echo "Nix Tmpfs Size:    ${NIX_TMPFS_SIZE}"
echo "Workspace Tmpfs:   ${WORKSPACE_TMPFS_SIZE}"
echo "Persistent Home:   ${HOST_HOME}"
echo "---------------------------"

$CONTAINER_RUNTIME run --rm -it \
  --cap-add SYS_ADMIN \
  --tmpfs /workspace:rw,size="$WORKSPACE_TMPFS_SIZE",exec \
  -v "$HOST_HOME":/persistent:rw,z \
  -v "$HOST_HOME"/.local/share/repx-store:/mnt/demirlie/.local/share/repx-store:z \
  -v "$HOST_HOME"/Desktop:/host-desktop:z \
  -v "$HOST_HOME"/Downloads:/host-downloads:z \
  docker.io/nixos/nix \
  nix-shell -p zstd gnutar util-linux coreutils rsync nix --run '
    set -e

    echo "Preparing in-memory Nix environment..."
    mkdir -p /nix-ram
    mount -t tmpfs -o rw,size='"${NIX_TMPFS_SIZE}"',exec tmpfs /nix-ram

    echo "Populating in-memory store from archive..."
    # cp /persistent/nix.tar.zst /tmp/
    # tar -I "zstd -d -T0" -xf /tmp/nix.tar.zst -C /nix-ram
    # rm /tmp/nix.tar.zst
    tar -I "zstd -d -T0" -xf /persistent/nix.tar.zst -C /nix-ram

    echo "Syncing bootstrap tools to in-memory store..."
    rsync -a /nix/store/ /nix-ram/store/

    echo "Activating in-memory Nix environment..."
    mount --move /nix-ram /nix

    echo "Setting up workspace..."
    # cp /persistent/workspace.tar.zst /tmp/
    # tar -I "zstd -d -T0" -xf /tmp/workspace.tar.zst -C /workspace
    # rm /tmp/workspace.tar.zst
    tar -I "zstd -d -T0" -xf /persistent/workspace.tar.zst -C /workspace

    mkdir -p /root/.config
    mkdir -p /root/.local/bin
    mkdir -p /root/.local/share

    ln -sf /workspace/Desktop /root/Desktop
    ln -sf /workspace/.bashrc /root/.bashrc
    ln -sf /workspace/Desktop/dotfiles/.config/* /root/.config
    ln -sf /workspace/Desktop/dotfiles/.local/bin/* /root/.local/bin

    echo "Workspace loaded. Executing into main Nix environment..."
    cd /root/Desktop/dotfiles
    rm -rf /root/.nix-profile
    nix profile install .#barebone --extra-experimental-features "nix-command flakes"
    exec bash -i
  '
