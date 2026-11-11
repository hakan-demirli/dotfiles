#!/usr/bin/env bash
set -euo pipefail

config=$1
owner=$(jq -r .owner "$config")
forge=$(jq -r .forge "$config")
github_api=$(jq -r .github.api "$config")
github_web=$(jq -r .github.web "$config")
github_ssh=$(jq -r .github.ssh "$config")
interval=$(jq -r .interval "$config")
excluded=$(jq -c .excluded "$config")

export GIT_TERMINAL_PROMPT=0

secret() {
  printf 'url=%s\n\n' "$1" | git credential fill | sed -n 's/^password=//p'
}

forge_token=$(secret "$forge")
github_token=$(secret "$github_web")
[[ -n $forge_token && -n $github_token ]]

request() {
  local token=$1 method=$2 url=$3
  shift 3
  curl -fsS -X "$method" -H 'Accept: application/json' -H 'Content-Type: application/json' \
    --config <(printf 'header = "Authorization: token %s"\n' "$token") "$@" "$url"
}

forgejo() {
  local method=$1 path=$2
  shift 2
  request "$forge_token" "$method" "$forge/api/v1$path" "$@"
}

github() {
  local method=$1 path=$2
  shift 2
  request "$github_token" "$method" "$github_api$path" "$@"
}

found() {
  local token=$1 url=$2 status
  status=$(curl -sS -o /dev/null -w '%{http_code}' \
    --config <(printf 'header = "Authorization: token %s"\n' "$token") "$url" || true)
  case $status in
    200) return 0 ;;
    404) return 1 ;;
    *)
      echo "fatal: GET $url returned HTTP $status" >&2
      exit 1
      ;;
  esac
}

mirror() {
  local name=$1 mirrors failures repository refs created remote sha
  local -a remotes commits
  mirrors=$(forgejo GET "/repos/$owner/$name/push_mirrors") || return 1

  if jq -e --arg name "$name" 'index($name) != null' <<< "$excluded" > /dev/null; then
    mapfile -t remotes < <(jq -r '.[].remote_name' <<< "$mirrors")
    for remote in "${remotes[@]}"; do
      echo "github-mirrors: removing the mirror of excluded $name"
      forgejo DELETE "/repos/$owner/$name/push_mirrors/$remote" -o /dev/null || return 1
    done
    return 0
  fi

  if [[ $(jq length <<< "$mirrors") -gt 0 ]]; then
    failures=$(jq -r --arg name "$name" \
      '.[] | select((.last_error // "") != "") | "github-mirrors: pushing \($name) failed: \(.last_error | split("\n")[0])"' \
      <<< "$mirrors") || return 1
    if [[ -n $failures ]]; then
      echo "$failures" >&2
      return 1
    fi
    return 0
  fi

  if found "$github_token" "$github_api/repos/$owner/$name"; then
    repository=$(github GET "/repos/$owner/$name") || return 1
    if [[ $(jq .fork <<< "$repository") != false ]]; then
      echo "github-mirrors: $owner/$name on GitHub is a fork; not mirroring $name" >&2
      return 1
    fi
    refs=$(git ls-remote --heads --tags "$github_web/$owner/$name") || return 1
    mapfile -t commits < <(awk 'NF == 2 {ref = $2; sub(/\^\{\}$/, "", ref); head[ref] = $1} END {for (ref in head) print head[ref]}' <<< "$refs")
    for sha in "${commits[@]}"; do
      if ! found "$forge_token" "$forge/api/v1/repos/$owner/$name/git/commits/$sha"; then
        echo "github-mirrors: $owner/$name on GitHub has $sha, which Forgejo lacks; not mirroring $name" >&2
        return 1
      fi
    done
  else
    echo "github-mirrors: creating private GitHub repository $owner/$name"
    jq -nc --arg name "$name" '{name: $name, private: true}' \
      | github POST /user/repos --data @- -o /dev/null || return 1
  fi

  created=$(jq -nc --arg address "$github_ssh/$owner/$name.git" --arg interval "$interval" \
    '{remote_address: $address, use_ssh: true, interval: $interval, sync_on_commit: true}' \
    | forgejo POST "/repos/$owner/$name/push_mirrors" --data @-) || return 1
  if ! jq -nc --arg key "$(jq -r .public_key <<< "$created")" '{title: "forgejo-push-mirror", key: $key, read_only: false}' \
    | github POST "/repos/$owner/$name/keys" --data @- -o /dev/null; then
    echo "github-mirrors: GitHub refused the deploy key of $name; removing its mirror" >&2
    forgejo DELETE "/repos/$owner/$name/push_mirrors/$(jq -r .remote_name <<< "$created")" -o /dev/null
    return 1
  fi
  forgejo POST "/repos/$owner/$name/push_mirrors-sync" -o /dev/null || return 1
  echo "github-mirrors: mirroring $name to GitHub"
}

repositories='[]'
page=1
while :; do
  batch=$(forgejo GET "/repos/search?limit=50&page=$page")
  [[ $(jq '.data | length' <<< "$batch") -gt 0 ]] || break
  owned=$(jq -c --arg owner "$owner" \
    '[.data[] | select(.owner.login == $owner) | {name, archived, mirror, fork, empty}]' <<< "$batch")
  repositories=$(jq -c --argjson owned "$owned" '. + $owned' <<< "$repositories")
  page=$((page + 1))
done

failed=0
while IFS= read -r name <&3; do
  mirror "$name" || failed=1
done 3< <(jq -r '.[] | select((.archived or .mirror or .fork or .empty) | not) | .name' <<< "$repositories")
exit "$failed"
