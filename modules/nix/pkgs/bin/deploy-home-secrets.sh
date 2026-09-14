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
  profile="$(id -un)@$(hostname -s)"
fi

flake="path:$repo"
allowed="$(nix eval --json "$flake#homeConfigurations.\"$profile\".config.homeSops.enable")"
[[ $allowed == true ]] || die "personal secret deployment is disabled for $profile"
configured_host="$(nix eval --raw "$flake#homeConfigurations.\"$profile\".config.home.sessionVariables.DOTFILES_HOST")"
[[ $configured_host == "$(hostname -s)" ]] || die "Home Manager profile $profile belongs to host $configured_host"
configured_user="$(nix eval --raw "$flake#homeConfigurations.\"$profile\".config.home.username")"
current_user="$(id -un)"
[[ $configured_user == "$current_user" ]] \
  || die "Home Manager profile $profile belongs to $configured_user, not $current_user"

identity_name="$(nix eval --raw "$flake#homeConfigurations.\"$profile\".config.homeSops.identity")"
key_file="$(nix eval --raw "$flake#homeConfigurations.\"$profile\".config.homeSops.ageKeyFile")"
state_repository="$(nix eval --json "$flake#homeConfigurations.\"$profile\".config.home.stateRepository")"
state_path="$(jq -er .path <<< "$state_repository")"
state_branch="$(jq -er .branch <<< "$state_repository")"
state_remote="$(jq -er .remote <<< "$state_repository")"
git check-ref-format --branch "$state_branch" > /dev/null

check_state_repository() {
  [[ $(git -C "$state_path" rev-parse --show-toplevel) == "$(realpath "$state_path")" ]] \
    || die "state path must be a Git working tree root: $state_path"
  [[ $(git -C "$state_path" symbolic-ref --quiet --short HEAD) == "$state_branch" ]] \
    || die "state checkout must use branch $state_branch; existing files were left in place"
  [[ $(git -C "$state_path" remote get-url origin) == "$state_remote" ]] \
    || die "state checkout has a different origin: $state_path"
}

if [[ -e $state_path || -L $state_path ]]; then
  check_state_repository
fi

envelope="$repo/secrets/identities/home-$identity_name.age.key.enc"
public_file="$repo/secrets/identities/home-$identity_name.age.pub"
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
checkout=""
trap 'rm -rf "$staging"; if [[ -n "$checkout" ]]; then rm -rf "$checkout"; fi' EXIT
identity="$staging/home-identity.key"

printf '\n[deploy-home-secrets] PASSPHRASE FOR: home-%s\n' "$identity_name" >&2
printf '[deploy-home-secrets] PURPOSE: Home Manager Git, SSH, and user secrets\n' >&2
if ! age --decrypt --output "$identity" "$envelope"; then
  die "could not decrypt the Home identity"
fi
chmod 0600 "$identity"

expected="$(tr -d '\n' < "$public_file")"
actual="$(age-keygen -y "$identity")"
[[ $actual == "$expected" ]] || die "Home identity has the wrong recipient"

install -d -m 0700 "$(dirname "$key_file")"
install -m 0600 "$identity" "$key_file"

bootstrap="$(nix build --no-link --print-out-paths "$flake#homeConfigurations.\"$profile\".config.homeSops.bootstrap")"
"$bootstrap/bin/bootstrap-home-secrets"

state_git() {
  GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    git -c credential.helper= -c "credential.helper=$bootstrap/bin/git-credential-sops-readonly" "$@"
}

if [[ -e $state_path || -L $state_path ]]; then
  check_state_repository
else
  mkdir -p "$(dirname "$state_path")"
  checkout="$(mktemp -d "$state_path.checkout.XXXXXX")"
  state_git init --initial-branch="$state_branch" "$checkout"
  state_git -C "$checkout" remote add origin "$state_remote"
  if state_git -C "$checkout" ls-remote --exit-code --heads origin "refs/heads/$state_branch" > "$staging/state-ref"; then
    state_git -C "$checkout" fetch --depth=1 origin "refs/heads/$state_branch:refs/remotes/origin/$state_branch"
    state_git -C "$checkout" checkout -B "$state_branch" --track "origin/$state_branch"
  else
    result=$?
    [[ $result == 2 ]] || die "could not inspect the remote state branch"
  fi
  mkdir -p "$checkout/.local/state/bash"
  mv --no-clobber --no-target-directory "$checkout" "$state_path"
  [[ ! -e $checkout ]] || die "state checkout appeared during provisioning: $state_path"
  checkout=""
fi
mkdir -p "$state_path/.local/state/bash"

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
