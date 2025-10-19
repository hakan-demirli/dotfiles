#!/usr/bin/env bash

CONTAINER_RUNTIME="docker"
HOST_HOME="$HOME"
DOTFILES_REPO="https://github.com/hakan-demirli/dotfiles"

usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Seeds the persistent storage with the initial Nix store and workspace archives."
  echo ""
  echo "Options:"
  echo "  -r, --runtime <name>     Container runtime to use (e.g., docker, podman)."
  echo "                           Default: ${CONTAINER_RUNTIME}"
  echo "  -H, --host-home <path>   Path on the host for persistent storage."
  echo "                           Default: ${HOST_HOME}"
  echo "  -g, --repo <url>         Git repository URL for the dotfiles."
  echo "                           Default: ${DOTFILES_REPO}"
  echo "  -h, --help               Display this help message and exit."
}

SHORT_OPTS="r:H:g:h"
LONG_OPTS="runtime:,host-home:,repo:,help"

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
    -H|--host-home)
      HOST_HOME="$2"
      shift 2
      ;;
    -g|--repo)
      DOTFILES_REPO="$2"
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

echo "--- Seeding Environment ---"
echo "Container Runtime: ${CONTAINER_RUNTIME}"
echo "Persistent Home:   ${HOST_HOME}"
echo "Dotfiles Repo:     ${DOTFILES_REPO}"
echo "---------------------------"

$CONTAINER_RUNTIME run --rm -it \
  -v "$HOST_HOME":/persistent:z \
  -e DOTFILES_REPO="$DOTFILES_REPO" \
  docker.io/nixos/nix \
  nix-shell -p zstd gnutar git openssl coreutils --run '
    set -e

    mkdir -p /root/Desktop

    echo "Cloning dotfiles from ${DOTFILES_REPO}..."
    git clone "${DOTFILES_REPO}" /root/Desktop/dotfiles

    echo "Creating .bashrc..."
    cat <<'"EOF"' > /root/.bashrc
if [ -f "$HOME/Desktop/dotfiles/.config/bash/main.sh" ]; then
  source "$HOME/Desktop/dotfiles/.config/bash/main.sh"
fi
if [ -f "$HOME/Desktop/dotfiles/.config/bash/container_helpers.sh" ]; then
  source "$HOME/Desktop/dotfiles/.config/bash/container_helpers.sh"
fi
EOF

    echo "Creating Nix store archive..."
    tar -I "zstd -1 -T0" -cpf /persistent/nix.tar.zst -C /nix .

    echo "Creating workspace archive..."
    tar -I "zstd -1 -T0" \
      --transform="s,^root,workspace," \
      -cf /persistent/workspace.tar.zst \
      /root/Desktop /root/.bashrc

    echo "Seeding complete!"
  '
