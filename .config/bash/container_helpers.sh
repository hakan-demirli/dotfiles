#!/usr/bin/env bash

persist-workspace() {
  echo "Saving workspace to persistent archives..."
  tar -cf - -C /nix . | zstd -1 -T0 > /persistent/nix.tar.zst && echo "nix.tar.zst saved." &
  tar -cf - -C /workspace . | zstd -1 -T0 > /persistent/workspace.tar.zst && echo "workspace.tar.zst saved." &
  wait
  echo "All archives saved!"
}

# openssl enc -aes-256-cbc -pbkdf2 -in ./secrets_raw.tar -out ./secrets.tar
# openssl enc -d -aes-256-cbc -pbkdf2 -in ./secrets.tar -out ./secrets_decrypted.tar
unlock-secrets() {
  local secrets_archive="/workspace/secrets.tar"
  local secrets_tmpfs_dir="/mem/secrets"
  local destination_dir="${secrets_tmpfs_dir}/git"
  local symlink_target_path="/root/.config/git"

  if [ ! -f "$secrets_archive" ]; then
    echo "Secrets archive not found at $secrets_archive"
    return 1
  fi

  if ! command -v openssl &> /dev/null; then
    echo "openssl is NOT in PATH"
    return 1
  fi

  local password
  read -rsp "Enter passphrase: " password && echo

  if ! head -c8 "$secrets_archive" | grep -q "^Salted__"; then
    echo "File does not appear to be a valid OpenSSL encrypted file."
    unset password
    return 1
  fi

  if ! openssl enc -d -aes-256-cbc -pbkdf2 -in "$secrets_archive" -pass stdin <<<"$password" >/dev/null 2>&1; then
    echo "Decryption failed. Incorrect passphrase?"
    unset password
    return 1
  fi

  echo "Passphrase correct. Deploying secrets..."
  rm -rf "$destination_dir"
  mkdir -p "$destination_dir"

  if openssl enc -d -aes-256-cbc -pbkdf2 -in "$secrets_archive" -pass stdin <<<"$password" | tar -xf - -C "$destination_dir"; then
    mkdir -p "$(dirname "$symlink_target_path")"
    ln -sfn "$destination_dir" "$symlink_target_path"
    echo "Decryption and deployment complete."
    echo "Symlinked ${symlink_target_path} -> ${destination_dir}"
  else
    echo "An unexpected error occurred during final extraction."
  fi

  unset password
}

if [ -n "$PS1" ]; then
  trap "echo; echo 'Exiting. Auto-persisting workspace to disk...'; persist-workspace" EXIT
fi
