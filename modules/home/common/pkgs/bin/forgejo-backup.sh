#!/usr/bin/env bash
set -euo pipefail

forge=$1
owner=$2
destination=$3
staging="$destination/.staging"

export GIT_TERMINAL_PROMPT=0
umask 077
mkdir -p "$destination"
exec 9> "$destination/.lock"
if ! flock -n 9; then
  echo "forgejo-backup: another backup of $destination is running" >&2
  exit 1
fi
rm -rf "$staging"
mkdir "$staging"

curl -fsS --retry 20 --retry-all-errors --retry-delay 30 --max-time 30 -o /dev/null "$forge/api/v1/version"

token=$(printf 'url=%s\n\n' "$forge" | git credential fill | sed -n 's/^password=//p')
[[ -n $token ]]

forgejo() {
  curl -fsS -H 'Accept: application/json' \
    --config <(printf 'header = "Authorization: token %s"\n' "$token") "$forge/api/v1$1"
}

keep() {
  local mirror=$1
  git -C "$mirror" config core.logAllRefUpdates always \
    && git -C "$mirror" config gc.reflogExpire never \
    && git -C "$mirror" config gc.reflogExpireUnreachable never
}

backup() {
  local name=$1 mirror="$destination/$1.git"
  if [[ -e $mirror ]]; then
    git -C "$mirror" remote set-url origin "$forge/$owner/$name" || return 1
    keep "$mirror" || return 1
    git -C "$mirror" fetch --quiet --no-prune --no-prune-tags origin || return 1
    return 0
  fi
  if ! git clone --quiet --mirror "$forge/$owner/$name" "$staging/$name.git" || ! keep "$staging/$name.git"; then
    rm -rf "${staging:?}/$name.git"
    return 1
  fi
  mv --no-target-directory "$staging/$name.git" "$mirror"
}

repositories='[]'
page=1
while :; do
  batch=$(forgejo "/repos/search?limit=50&page=$page")
  [[ $(jq '.data | length' <<< "$batch") -gt 0 ]] || break
  owned=$(jq -c --arg owner "$owner" '[.data[] | select(.owner.login == $owner) | .name]' <<< "$batch")
  repositories=$(jq -c --argjson owned "$owned" '. + $owned' <<< "$repositories")
  page=$((page + 1))
done

failed=0
while IFS= read -r name <&3; do
  if ! backup "$name"; then
    echo "forgejo-backup: backing up $name failed" >&2
    failed=1
  fi
done 3< <(jq -r '.[]' <<< "$repositories")
exit "$failed"
