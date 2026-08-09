# shellcheck shell=bash
set -euo pipefail

umask 077

usage() {
  cat << 'EOF'
Usage: deploy-home-secrets [options]

Options:
  --repo PATH       Dotfiles repository (default: current directory)
  --profile NAME    Home Manager configuration (default: inferred from hostname)
  --check           Validate inputs without decrypting or deploying
  -h, --help        Show this help
EOF
}

log() {
  printf '[deploy-home-secrets] %s\n' "$*" >&2
}

die() {
  log "ERROR: $*"
  exit 1
}

repo="$(pwd -P)"
profile=""
check_only=0

while (($# > 0)); do
  case $1 in
    --repo)
      repo=$2
      shift 2
      ;;
    --profile)
      profile=$2
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

if [[ -z $profile ]]; then
  case $(hostname -s) in
    laptop-0) profile="user-0@desktop-nvidia" ;;
    laptop-1) profile="user-0@desktop" ;;
    vps-oracle-0) profile="user-0@vps-oracle-0" ;;
    *) profile="user-0@headless" ;;
  esac
fi

flake="path:$repo"
configured_user="$(nix eval --raw "$flake#homeConfigurations.\"$profile\".config.home.username")"
current_user="$(id -un)"
[[ $configured_user == "$current_user" ]] \
  || die "Home Manager profile $profile belongs to $configured_user, not $current_user"

envelope="$repo/secrets/identities/home-user-0.age.key.enc"
public_file="$repo/secrets/identities/home-user-0.age.pub"
[[ -s $envelope ]] || die "Home identity envelope is missing: $envelope"
[[ -s $public_file ]] || die "Home identity recipient is missing: $public_file"
grep -Fq -- '-----BEGIN AGE ENCRYPTED FILE-----' "$envelope" \
  || die "Home identity envelope is not armored age data"

if ((check_only)); then
  log "Inputs are ready for profile=$profile"
  exit 0
fi

staging="$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/deploy-home-secrets.XXXXXX")"
chmod 0700 "$staging"
trap 'rm -rf "$staging"' EXIT
identity="$staging/home-user-0.key"

printf '\n[deploy-home-secrets] PASSPHRASE FOR: home-user-0\n' >&2
printf '[deploy-home-secrets] PURPOSE: Home Manager Git, SSH, and user secrets\n' >&2
if ! age --decrypt --output "$identity" "$envelope"; then
  die "could not decrypt the Home identity"
fi
chmod 0600 "$identity"

expected="$(tr -d '\n' < "$public_file")"
actual="$(age-keygen -y "$identity")"
[[ $actual == "$expected" ]] || die "Home identity has the wrong recipient"

install -d -m 0700 "$HOME/.config/sops/age"
install -m 0600 "$identity" "$HOME/.config/sops/age/keys.txt"

log "Activating Home Manager profile $profile"
home-manager switch --flake "$flake#$profile"

outputs=(
  "$HOME/.config/git/git_users"
  "$HOME/.config/sops-nix/secrets/git_tokens"
  "$HOME/.ssh/id_ed25519"
  "$HOME/.ssh/id_ed25519_proton"
  "$HOME/.ssh/id_ed25519_sf"
)
for output in "${outputs[@]}"; do
  [[ -s $output ]] || die "deployed Home secret is missing: $output"
done

log "Home secret deployment complete for profile=$profile"
