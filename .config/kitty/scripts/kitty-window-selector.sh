#!/usr/bin/env bash
# shellcheck disable=SC2086,SC2016

if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed."
  exit 1
fi

self_id="$KITTY_WINDOW_ID"

json_data=$(kitty @ ls)

current_tab_json=$(echo "$json_data" | jq -r --arg self_id "$self_id" '
  .[].tabs[] | select(.windows[].id == ($self_id | tonumber))
')

history_ids=$(echo "$current_tab_json" | jq -r '.active_window_history[]')
tab_window_ids=$(echo "$current_tab_json" | jq -r '.windows[].id')

target_id=""
for hid in $history_ids; do
  if [[ $hid != "$self_id" ]]; then
    target_id="$hid"
    break
  fi
done

if [[ -z $target_id ]]; then
  candidate=""
  for wid in $tab_window_ids; do
    if [[ $wid != "$self_id" ]]; then
      candidate="$wid"
    fi
  done

  if [[ -n $candidate ]]; then
    target_id="$candidate"
  fi
fi

declare -a windows
target_index=-1
current_idx=0

while IFS='|' read -r id title; do
  if [[ $id == "$self_id" ]]; then
    continue
  fi

  line="WIN: $title ($id)"
  windows+=("$line")

  if [[ $id == "$target_id" ]]; then
    target_index=$current_idx
  fi

  ((current_idx++))
done < <(echo "$json_data" | jq -r '.[].tabs[].windows[] | "\(.id)|\(.title)"')

fzf_bind_arg=""
if [[ $target_index -ge 0 ]]; then
  pos=$((target_index + 1))
  fzf_bind_arg="--sync --bind=start:pos($pos)"
fi

{
  for win in "${windows[@]}"; do echo "$win"; done
} | fzf --margin=20%,20% --border $fzf_bind_arg \
  --preview '
      if [[ {} == "WIN:"* ]]; then
        id=$(echo {} | sed "s/.*(\([0-9]*\))$/\1/")
        kitty @ get-text --match id:$id --ansi
      fi
    ' | {
  read -r selection
  if [[ -z $selection ]]; then
    exit 0
  fi

  if [[ $selection == WIN:* ]]; then
    id="${selection##*(}"
    id="${id%)}"

    kitty @ focus-window -m "id:$id"
  fi
}
