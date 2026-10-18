#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/hakan-demirli/code_templates"
CACHE_DIR="$HOME/.cache/np_templates"
IGNORE_DIRS=(".git" "_deprecated")

function update_cache() {
  if [ -d "$CACHE_DIR" ]; then
    echo "Updating cache..."
    git -C "$CACHE_DIR" pull
  else
    echo "Cloning templates..."
    mkdir -p "$(dirname "$CACHE_DIR")"
    git clone --depth 1 "$REPO_URL" "$CACHE_DIR"
  fi
}

if [[ $# -gt 1 ]]; then
  echo "Usage: $(basename "$0") [pull|template]" >&2
  exit 1
fi

if [[ ${1:-} == "pull" ]]; then
  update_cache
  exit 0
fi

if [ ! -d "$CACHE_DIR" ]; then
  echo "Cache not found. Please run 'np.sh pull' first."
  exit 1
fi

find_args=("$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d)
for dir in "${IGNORE_DIRS[@]}"; do
  find_args+=(! -name "$dir")
done
find_args+=(-printf "%f\n")

mapfile -t templates < <(find "${find_args[@]}" | sort)

if [[ $# -eq 1 ]]; then
  selected=""
  for template in "${templates[@]}"; do
    if [[ $template == "$1" ]]; then
      selected=$template
      break
    fi
  done
  if [[ -z $selected ]]; then
    echo "Error: Unknown template '$1'" >&2
    exit 1
  fi
else
  selected=$(printf '%s\n' "${templates[@]}" | fzf)
fi

if [ -n "$selected" ]; then
  if [ -d "$selected" ]; then
    echo "Directory '$selected' already exists."
    exit 1
  fi
  cp -r "$CACHE_DIR/$selected" .
  echo "Project copied to: $(pwd)/$selected"
fi
