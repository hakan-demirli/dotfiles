#!/usr/bin/env bash

if (($# != 2)); then
  echo "usage: home-generation-replay-collisions USER HOME" >&2
  exit 2
fi

username=$1
home=${2%/}
control="$home/.storage/control"
backup_root="$control/replay-collisions"

if [[ ! -e "$control/current" && ! -L "$control/current" ]]; then
  exit 0
fi

if [[ ! -L "$control/current" ]]; then
  echo "home-generation-replay-collisions: $control/current is not a generation link" >&2
  exit 1
fi

current_target=$(readlink -- "$control/current")
case "$current_target" in
  generations/*/home-storage-policy)
    generation_id="${current_target#generations/}"
    generation_id="${generation_id%/home-storage-policy}"
    ;;
  generations/*)
    legacy_id="${current_target#generations/}"
    if [[ -n $legacy_id && $legacy_id != */* ]]; then
      exit 0
    fi
    echo "home-generation-replay-collisions: invalid current target: $current_target" >&2
    exit 1
    ;;
  *)
    echo "home-generation-replay-collisions: invalid current target: $current_target" >&2
    exit 1
    ;;
esac

if [[ -z $generation_id || $generation_id == */* ]]; then
  echo "home-generation-replay-collisions: invalid generation ID: $generation_id" >&2
  exit 1
fi

generation=$(readlink -e -- "$control/generations/$generation_id" 2> /dev/null || true)
case "$generation" in
  /nix/store/*-home-manager-generation) ;;
  *)
    echo "home-generation-replay-collisions: generation is not an immutable Home Manager closure" >&2
    exit 1
    ;;
esac

home_files=$(readlink -e -- "$generation/home-files" 2> /dev/null || true)
profile_directory="$home/.local/state/nix/profiles"
if [[ -z $home_files || ! -d $home_files || ! -d "$generation/home-path" || ! -x "$generation/boot-replay" ]]; then
  echo "home-generation-replay-collisions: incomplete generation: $generation" >&2
  exit 1
fi

if [[ -L $backup_root || (-e $backup_root && ! -d $backup_root) ]]; then
  previous="$control/replay-collisions.previous"
  rm -rf -- "$previous"
  mv -T -- "$backup_root" "$previous"
fi
mkdir -p -- "$backup_root"

backup_collision() {
  local target=$1
  local relative key slot

  case "$target" in
    "$home"/*) relative=${target#"$home"/} ;;
    *)
      echo "home-generation-replay-collisions: target escapes home: $target" >&2
      exit 1
      ;;
  esac

  key=$(printf '%s\0' "$relative" | sha256sum)
  key=${key%% *}
  slot="$backup_root/$key"
  rm -rf -- "$slot"
  mkdir -- "$slot"
  printf '%s\0' "$relative" > "$slot/path"
  mv -T -- "$target" "$slot/value"
  echo "home-generation-replay-collisions: preserved $target at $slot/value"
}

ensure_parents() {
  local target=$1
  local parent remaining component current

  parent=${target%/*}
  case "$parent" in
    "$home") return ;;
    "$home"/*) remaining=${parent#"$home"/} ;;
    *)
      echo "home-generation-replay-collisions: target escapes home: $target" >&2
      exit 1
      ;;
  esac

  current=$home
  while [[ -n $remaining ]]; do
    if [[ $remaining == */* ]]; then
      component=${remaining%%/*}
      remaining=${remaining#*/}
    else
      component=$remaining
      remaining=
    fi
    current="$current/$component"

    if [[ -d $current ]]; then
      continue
    fi
    if [[ -e $current || -L $current ]]; then
      backup_collision "$current"
    fi
    mkdir -- "$current"
  done
}

prepare_managed() {
  local source=$1
  local target=$2
  local current_source

  ensure_parents "$target"
  if [[ ! -e $target && ! -L $target ]]; then
    return
  fi
  if [[ -f $target ]] && cmp -s -- "$source" "$target"; then
    return
  fi
  if [[ -L $target ]]; then
    current_source=$(readlink -- "$target")
    case "$current_source" in
      /nix/store/*-home-manager-files/*) return ;;
    esac
  fi
  backup_collision "$target"
}

prepare_managed_link() {
  local target=$1
  local expected=$2
  local resolved_suffix=$3
  local current_source resolved

  ensure_parents "$target"
  if [[ ! -e $target && ! -L $target ]]; then
    return
  fi
  if [[ -L $target ]]; then
    current_source=$(readlink -- "$target")
    if [[ -n $expected && $current_source == "$expected" ]]; then
      return
    fi
    resolved=$(readlink -e -- "$target" 2> /dev/null || true)
    if [[ -n $resolved_suffix && $resolved == /nix/store/*-"$resolved_suffix" ]]; then
      return
    fi
  fi
  backup_collision "$target"
}

while IFS= read -r -d "" source; do
  relative=${source#"$home_files"/}
  case "$relative" in
    .storage | .storage/*)
      echo "home-generation-replay-collisions: generation attempts to manage reserved path $relative" >&2
      exit 1
      ;;
  esac
  prepare_managed "$source" "$home/$relative"
done < <(find "$home_files" \( -type f -o -type l \) -print0)

prepare_managed_link "$profile_directory/profile-1-link" "" "home-manager-path"
prepare_managed_link "$profile_directory/profile" "profile-1-link" ""
prepare_managed_link "$home/.nix-profile" "$profile_directory/profile" ""
prepare_managed_link "$home/.local/state/home-manager/gcroots/current-home" "" "home-manager-generation"

echo "home-generation-replay-collisions: prepared $username for $generation"
