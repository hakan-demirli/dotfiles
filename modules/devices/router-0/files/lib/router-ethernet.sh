#!/bin/sh

ROUTER_ETHERNET_LAN_PORT=eth1
ROUTER_ETHERNET_ROLE_PORT=eth0
ROUTER_ETHERNET_WAN_METRIC=10

router_ethernet_bridge() (
  i=0
  while :; do
    name=$(uci -q get "network.@device[$i].name") || break
    [ -n "$name" ] || break
    if [ "$name" = "br-lan" ]; then
      printf '@device[%d]' "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
)

router_ethernet_wan_zone() (
  i=0
  while :; do
    name=$(uci -q get "firewall.@zone[$i].name") || break
    [ -n "$name" ] || break
    if [ "$name" = "wan" ]; then
      printf '@zone[%d]' "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
)

router_ethernet_bridge_has_port() (
  uci -q get "network.$1.ports" 2> /dev/null | tr ' ' '\n' | grep -qxF "$2"
)

router_ethernet_mode() (
  bridge=$(router_ethernet_bridge) || {
    printf 'unknown'
    return 0
  }

  router_ethernet_bridge_has_port "$bridge" "$ROUTER_ETHERNET_ROLE_PORT" \
    && role_bridged=1 || role_bridged=0
  [ -n "$(uci -q get network.wan 2> /dev/null)" ] && wan_present=1 || wan_present=0

  if [ "$role_bridged" = "1" ] && [ "$wan_present" = "0" ]; then
    printf 'dual-lan'
  elif [ "$role_bridged" = "0" ] && [ "$wan_present" = "1" ]; then
    printf 'wired-wan'
  else
    printf 'unknown'
  fi
)

router_ethernet_desired_mode() (
  mode=$(uci -q get router.ethernet.mode 2> /dev/null)
  case $mode in
    dual-lan | wired-wan) printf '%s' "$mode" ;;
    *) printf 'dual-lan' ;;
  esac
)

router_ethernet_set_wan_zone() (
  zone=$(router_ethernet_wan_zone) || return 1

  uci -q delete "firewall.$zone.network"
  for entry in "$@"; do
    uci -q add_list "firewall.$zone.network=$entry"
  done
  uci -q add_list "firewall.$zone.network=wwan"
)

router_ethernet_apply_dual_lan() (
  bridge=$(router_ethernet_bridge) || return 1

  uci -q delete network.wan
  uci -q delete network.wan6

  uci -q delete "network.$bridge.ports"
  uci -q add_list "network.$bridge.ports=$ROUTER_ETHERNET_ROLE_PORT"
  uci -q add_list "network.$bridge.ports=$ROUTER_ETHERNET_LAN_PORT"

  router_ethernet_set_wan_zone
)

router_ethernet_apply_wired_wan() (
  bridge=$(router_ethernet_bridge) || return 1

  uci -q delete "network.$bridge.ports"
  uci -q add_list "network.$bridge.ports=$ROUTER_ETHERNET_LAN_PORT"

  uci -q set network.wan=interface
  uci -q set "network.wan.device=$ROUTER_ETHERNET_ROLE_PORT"
  uci -q set network.wan.proto=dhcp
  uci -q set "network.wan.metric=$ROUTER_ETHERNET_WAN_METRIC"

  uci -q set network.wan6=interface
  uci -q set "network.wan6.device=$ROUTER_ETHERNET_ROLE_PORT"
  uci -q set network.wan6.proto=dhcpv6
  uci -q set "network.wan6.metric=$ROUTER_ETHERNET_WAN_METRIC"

  router_ethernet_set_wan_zone wan wan6
)

router_ethernet_stage() {
  case $1 in
    dual-lan) router_ethernet_apply_dual_lan ;;
    wired-wan) router_ethernet_apply_wired_wan ;;
    *) return 1 ;;
  esac
}

router_ethernet_commit() {
  uci -q commit network
  uci -q commit firewall
}
