#!/bin/sh

ROUTER_CAPTIVE_DIR=/etc/router-captive
ROUTER_CAPTIVE_GUARD="$ROUTER_CAPTIVE_DIR/bypass"
ROUTER_CAPTIVE_DNSMASQ='dhcp.@dnsmasq[0]'
ROUTER_CAPTIVE_STATE_FILE=/var/run/router-captive.state

router_captive_cfg() (
  value=$(uci -q get "router.captive.$1" 2> /dev/null)
  [ -n "$value" ] || value=$2
  printf '%s' "$value"
)

router_captive_cfg_int() (
  value=$(router_captive_cfg "$1" "$2")
  case $value in
    '' | *[!0-9]*) printf '%s' "$2" ;;
    *) printf '%s' "$value" ;;
  esac
)

router_captive_gateway_url() (
  gateway=$(ip -4 route show default 2> /dev/null | sed -n 's/^default via \([0-9.]*\).*/\1/p' | head -1)
  [ -n "$gateway" ] || return 0
  printf 'http://%s' "$gateway"
)

router_captive_probe() (
  raw=$(curl -s -o /dev/null -m "$2" \
    -w '%{http_code} %{redirect_url}' "$1" 2> /dev/null) || {
    printf 'offline '
    return 0
  }

  code=${raw%% *}
  redirect=${raw#* }

  case $code in
    204)
      printf 'online '
      ;;
    000 | '')
      printf 'offline '
      ;;
    *)
      [ -n "$redirect" ] || redirect=$(router_captive_gateway_url)
      printf 'portal %s' "$redirect"
      ;;
  esac
)

router_captive_host_from_url() (
  host=${1#*://}
  host=${host%%/*}
  host=${host%%\?*}
  host=${host%%#*}
  host=${host##*@}
  host=${host%%:*}
  printf '%s' "$host"
)

router_captive_is_ipv4() {
  case $1 in
    '' | *[!0-9.]*) return 1 ;;
    *) return 0 ;;
  esac
}

router_captive_domains_for_host() (
  [ -n "$1" ] || return 0
  printf '%s\n' "$1"
  parent=${1#*.}
  [ "$parent" != "$1" ] || return 0
  case $parent in
    *.*) printf '%s\n' "$parent" ;;
  esac
)

router_captive_publish_state() {
  printf '%s\n%s\n%s\n' "$1" "$2" "$(date +%s)" > "$ROUTER_CAPTIVE_STATE_FILE.new"
  mv "$ROUTER_CAPTIVE_STATE_FILE.new" "$ROUTER_CAPTIVE_STATE_FILE"
}

router_captive_state() (
  [ -s "$ROUTER_CAPTIVE_STATE_FILE" ] || return 1
  state=$(sed -n 1p "$ROUTER_CAPTIVE_STATE_FILE")
  case $state in
    online | portal | offline) printf '%s' "$state" ;;
    *) return 1 ;;
  esac
)

router_captive_state_url() (
  router_captive_state > /dev/null || return 1
  sed -n 2p "$ROUTER_CAPTIVE_STATE_FILE"
)

router_captive_state_age() (
  router_captive_state > /dev/null || return 1
  written=$(sed -n 3p "$ROUTER_CAPTIVE_STATE_FILE")
  case $written in
    '' | *[!0-9]*) return 1 ;;
  esac
  age=$(($(date +%s) - written))
  [ "$age" -lt 0 ] && age=0
  printf '%s' "$age"
)

router_captive_rebind_protected() {
  [ "$(uci -q get "$ROUTER_CAPTIVE_DNSMASQ.rebind_protection")" = "1" ]
}

router_captive_allowlisted() {
  uci -q get "$ROUTER_CAPTIVE_DNSMASQ.rebind_domain" 2> /dev/null \
    | tr ' ' '\n' | grep -qxF "$1"
}

router_captive_bypass_active() {
  [ -s "$ROUTER_CAPTIVE_GUARD" ]
}

router_captive_bypass_started() (
  router_captive_bypass_active || return 0
  started=$(sed -n 1p "$ROUTER_CAPTIVE_GUARD" 2> /dev/null)
  case $started in
    '' | *[!0-9]*) return 0 ;;
    *) printf '%s' "$started" ;;
  esac
)

router_captive_bypass_domains() {
  router_captive_bypass_active || return 0
  sed 1d "$ROUTER_CAPTIVE_GUARD" 2> /dev/null
}

router_captive_reload_dnsmasq() {
  uci -q commit dhcp
  /etc/init.d/dnsmasq reload > /dev/null 2>&1
}

router_captive_bypass() (
  router_captive_rebind_protected || return 1
  [ -n "$1" ] || return 1
  router_captive_is_ipv4 "$1" && return 1

  pending=''
  for domain in $(router_captive_domains_for_host "$1"); do
    router_captive_allowlisted "$domain" && continue
    pending="$pending$domain
"
  done
  [ -n "$pending" ] || return 1

  started=$(router_captive_bypass_started)
  [ -n "$started" ] || started=$(date +%s)

  mkdir -p "$ROUTER_CAPTIVE_DIR"
  chmod 0700 "$ROUTER_CAPTIVE_DIR"

  {
    printf '%s\n' "$started"
    router_captive_bypass_domains
    printf '%s' "$pending"
  } > "$ROUTER_CAPTIVE_GUARD.new"
  mv "$ROUTER_CAPTIVE_GUARD.new" "$ROUTER_CAPTIVE_GUARD"

  printf '%s' "$pending" | while IFS= read -r domain; do
    [ -n "$domain" ] || continue
    uci -q add_list "$ROUTER_CAPTIVE_DNSMASQ.rebind_domain=$domain"
  done

  router_captive_reload_dnsmasq
  return 0
)

router_captive_restore() (
  router_captive_bypass_active || return 1

  router_captive_bypass_domains | while IFS= read -r domain; do
    [ -n "$domain" ] || continue
    uci -q del_list "$ROUTER_CAPTIVE_DNSMASQ.rebind_domain=$domain"
  done

  router_captive_reload_dnsmasq
  rm -f "$ROUTER_CAPTIVE_GUARD"
  return 0
)
