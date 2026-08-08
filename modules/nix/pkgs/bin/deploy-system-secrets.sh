set -euo pipefail

umask 077

usage() {
  cat << 'EOF'
Usage: deploy-system-secrets [options]

Options:
  --repo PATH       Dotfiles repository (default: current directory)
  --host HOST       NixOS configuration (default: current hostname)
  --check           Validate inputs without decrypting or deploying
  -h, --help        Show this help
EOF
}

log() {
  printf '[deploy-system-secrets] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

repo="$(pwd -P)"
host="$(hostname -s)"
check_only=0

while (($# > 0)); do
  case $1 in
    --repo)
      repo=$2
      shift 2
      ;;
    --host)
      host=$2
      shift 2
      ;;
    --check)
      check_only=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

repo="$(realpath -m "$repo")"
[[ -f $repo/flake.nix ]] || die "repository is not a flake: $repo"
[[ $EUID -ne 0 ]] || die "run this command as the target user, not root"

flake="path:$repo"
configured_host="$(nix eval --raw "$flake#nixosConfigurations.$host.config.networking.hostName")"
[[ $configured_host == "$host" ]] || die "NixOS configuration does not match host: $host"
sudo_command=/run/wrappers/bin/sudo
[[ -x $sudo_command ]] || die "NixOS sudo wrapper is missing: $sudo_command"

password_envelope="$repo/secrets/bootstrap/password.age.key.enc"
password_pub="$repo/secrets/bootstrap/password.age.pub"
tailscale_envelope="$repo/secrets/bootstrap/tailscale.age.key.enc"
tailscale_pub="$repo/secrets/bootstrap/tailscale.age.pub"

if [[ $host == vps-oracle-0 ]]; then
  system_name="vps-oracle-0"
  system_purpose="VPS host system SOPS identity"
  system_envelope="$repo/secrets/identities/vps-oracle-0.age.key.enc"
  system_pub="$repo/secrets/identities/vps-oracle-0.age.pub"
else
  system_name="system-admin"
  system_purpose="system services and Munge SOPS identity"
  system_envelope="$repo/secrets/system.age.key.enc"
  system_pub="$repo/secrets/system.age.pub"
fi

for file in \
  "$system_envelope" "$system_pub" \
  "$password_envelope" "$password_pub" \
  "$tailscale_envelope" "$tailscale_pub"; do
  [[ -s $file ]] || die "required deployment input is missing: $file"
done

for envelope in "$system_envelope" "$password_envelope" "$tailscale_envelope"; do
  grep -Fq -- '-----BEGIN AGE ENCRYPTED FILE-----' "$envelope" \
    || die "identity envelope is not armored age data: $envelope"
done

if ((check_only)); then
  log "Inputs are ready for host=$host"
  exit 0
fi

mountpoint -q /persist || die "/persist is not mounted"
"$sudo_command" -v

staging="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/deploy-system-secrets.XXXXXX")"
chmod 0700 "$staging"
trap 'rm -rf "$staging"' EXIT

decrypt_identity() {
  local name=$1
  local purpose=$2
  local envelope=$3
  local public_file=$4
  local output=$5
  local expected actual

  printf '\n[deploy-system-secrets] PASSPHRASE FOR: %s\n' "$name" >&2
  printf '[deploy-system-secrets] PURPOSE: %s\n' "$purpose" >&2
  if ! age --decrypt --output "$output" "$envelope"; then
    rm -f "$output"
    die "could not decrypt $name identity"
  fi
  chmod 0600 "$output"

  expected="$(tr -d '\n' < "$public_file")"
  actual="$(age-keygen -y "$output")"
  [[ $actual == "$expected" ]] || die "$name identity has the wrong recipient"
}

decrypt_identity \
  "$system_name" \
  "$system_purpose" \
  "$system_envelope" \
  "$system_pub" \
  "$staging/system.key"
decrypt_identity \
  password-bootstrap \
  "local login password hashes" \
  "$password_envelope" \
  "$password_pub" \
  "$staging/password.key"
decrypt_identity \
  tailscale-bootstrap \
  "Tailscale enrollment secret" \
  "$tailscale_envelope" \
  "$tailscale_pub" \
  "$staging/tailscale.key"

"$sudo_command" -v
"$sudo_command" install -d -m 0700 /persist/system/var/lib/sops-nix
"$sudo_command" install -m 0600 "$staging/system.key" /persist/system/var/lib/sops-nix/key.txt
"$sudo_command" install -m 0600 "$staging/password.key" /persist/system/var/lib/sops-nix/bootstrap-password.key
"$sudo_command" install -m 0600 "$staging/tailscale.key" /persist/system/var/lib/sops-nix/bootstrap-tailscale.key
"$sudo_command" sync /persist/system/var/lib/sops-nix

log "Switching NixOS host $host"
"$sudo_command" nixos-rebuild switch --flake "$flake#$host"

"$sudo_command" test -s /persist/system/var/lib/sops-nix/key.txt
"$sudo_command" test -s /persist/system/var/lib/sops-nix/bootstrap-password.key
"$sudo_command" test -s /persist/system/var/lib/sops-nix/bootstrap-tailscale.key
"$sudo_command" test -s /etc/munge/munge.key
"$sudo_command" test -s /root/.ssh/id_ed25519_proton

log "System secret deployment complete for host=$host"
