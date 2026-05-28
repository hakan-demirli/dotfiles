#!/usr/bin/env bash
set -uo pipefail

WARP_CLI_BIN="/run/current-system/sw/bin/warp-cli"

if [[ ! -x $WARP_CLI_BIN ]]; then
  echo "ERROR: '$WARP_CLI_BIN' is not executable."
  echo "Please edit this script and set the correct path to the warp-cli binary."
  exit 1
fi

WARP_CLI=("$WARP_CLI_BIN" --accept-tos)

command -v grep > /dev/null 2>&1 || {
  echo >&2 "ERROR: 'grep' command not found. Please install it."
  exit 1
}
command -v sleep > /dev/null 2>&1 || {
  echo >&2 "ERROR: 'sleep' command not found. Please install coreutils."
  exit 1
}

log_dir=$(mktemp -d)
trap 'rm -rf "$log_dir"' EXIT
reg_log="$log_dir/warp_reg_stderr.log"
connect_log="$log_dir/warp_connect_stderr.log"

echo "Checking current Warp status..."
if "${WARP_CLI[@]}" status 2> /dev/null | grep -q "Status update: Connected"; then
  echo "Warp is already connected."
  "${WARP_CLI[@]}" status
  exit 0
else
  echo "Warp is not connected or status unavailable. Proceeding with setup..."
fi

echo "Attempting Warp registration (accepting ToS automatically)..."

if ! "${WARP_CLI[@]}" registration new 2> "$reg_log"; then

  if ! grep -q -E 'Old registration is still around|Registration is missing|already registered|Device is already registered' "$reg_log"; then
    echo "ERROR: Warp registration failed unexpectedly! See details below."
    cat "$reg_log"

    exit 1
  else
    echo "Warp already registered or registration missing (handled). Proceeding."
  fi
else
  echo "Warp registration successful."
fi

echo "Attempting Warp connect..."

if ! "${WARP_CLI[@]}" connect 2> "$connect_log"; then
  echo "ERROR: warp-cli connect command failed! See details below."
  cat "$connect_log"

  "${WARP_CLI[@]}" status || echo "Could not get Warp status after connect failure."
  exit 1
fi

echo "Verifying Warp connection status (waiting up to 15s)..."
ATTEMPTS=5
CONNECTED=false
for ((i = 1; i <= ATTEMPTS; i++)); do

  if "${WARP_CLI[@]}" status | grep -q ".*Connected.*"; then
    CONNECTED=true
    break
  fi
  echo "Warp not connected yet (Attempt $i/$ATTEMPTS). Waiting 3 seconds..."
  sleep 3
done

if $CONNECTED; then
  echo "Warp successfully connected."
  "${WARP_CLI[@]}" status
  exit 0
else
  echo "ERROR: Warp status is not 'Connected' after $ATTEMPTS attempts."
  "${WARP_CLI[@]}" status
  exit 1
fi
