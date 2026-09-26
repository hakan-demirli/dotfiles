#!/bin/sh

ROUTER_USBWAN_INTERFACE=usbwan

router_usbwan_is_usb() (
  case $(readlink -f "/sys/class/net/$1/device" 2> /dev/null) in
    */usb[0-9]*/*) return 0 ;;
  esac
  return 1
)

router_usbwan_candidate() (
  for path in /sys/class/net/*; do
    name=${path##*/}
    if router_usbwan_is_usb "$name"; then
      printf '%s' "$name"
      return 0
    fi
  done
  return 1
)

router_usbwan_device() (
  ubus call "network.interface.$ROUTER_USBWAN_INTERFACE" status 2> /dev/null \
    | jsonfilter -e '@.device' 2> /dev/null
)

router_usbwan_reconcile() (
  current=$(router_usbwan_device)
  [ -n "$current" ] && [ -e "/sys/class/net/$current" ] && return 0

  device=$(router_usbwan_candidate) || return 0
  logger -t router-usbwan "using $device as the usb uplink"
  ubus call "network.interface.$ROUTER_USBWAN_INTERFACE" add_device \
    "{\"name\":\"$device\",\"link-ext\":false}"
)
