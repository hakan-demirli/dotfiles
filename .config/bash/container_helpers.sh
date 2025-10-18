#!/usr/bin/env bash

persist-workspace() {
  echo "Saving workspace to persistent archives..."
  tar -I "zstd -1 -T0" -cf /persistent/nix.tar.zst -C /nix ./store && echo "nix.tar.zst saved." &
  tar -I "zstd -1 -T0" -cf /persistent/workspace.tar.zst /workspace && echo "workspace.tar.zst saved." &
  wait
  echo "All archives saved!"
}

unlock-secrets() {
  local secrets_archive="/root/Desktop/dotfiles/secrets.tar"
  if [ ! -f "$secrets_archive" ]; then
    echo "Secrets archive not found at $secrets_archive"
    return 1
  fi

  local password
  read -rsp "Enter passphrase: " password && echo

  if ! head -c8 "$secrets_archive" | grep -q "^Salted__"; then
    echo "File does not appear to be a valid OpenSSL encrypted file."
    unset password
    return 1
  fi

  if openssl enc -d -aes-256-cbc -pbkdf2 -in "$secrets_archive" -pass stdin <<<"$password" | tar -xf - -C /root/Desktop/dotfiles; then
    echo "Decryption and deployment complete."
  else
    echo "Decryption failed. Incorrect passphrase?"
  fi

  unset password
}

if [ -n "$PS1" ]; then
  trap "echo; echo 'Exiting. Auto-persisting workspace to disk...'; persist-workspace" EXIT
fi
