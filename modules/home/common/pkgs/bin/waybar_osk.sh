#!/usr/bin/env bash

state_dir="${XDG_RUNTIME_DIR:-/run/user/$UID}"
tablet="$(cat "$state_dir/tablet_mode" 2> /dev/null)"
visible="$(cat "$state_dir/wvkbd_visible" 2> /dev/null)"

if [[ $tablet != "on" && $visible != "1" ]]; then
  printf '{"text":"","tooltip":"","class":"osk-hidden","alt":"hidden"}\n'
  exit 0
fi

if [[ $visible == "1" ]]; then
  printf '{"text":"\uf11c","tooltip":"Hide on-screen keyboard","class":"osk-on","alt":"on"}\n'
else
  printf '{"text":"\uf11c","tooltip":"Show on-screen keyboard","class":"osk-off","alt":"off"}\n'
fi
