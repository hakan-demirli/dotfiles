#!/usr/bin/env bash
set -euo pipefail

bind_line=${1-}
bind_window=${2-}

IFS='|' read -r tmux_cwd tmux_session_id tmux_window_active tmux_pane_path <<< "$(tmux display-message -p '#{session_path}|#{session_id}|#{window_id}|#{pane_current_path}')"
tmux_cwd_hash=$(echo -n "$tmux_cwd" | md5sum)
tmux_cwd_hash=${tmux_cwd_hash%% *}
cache_dir="$HOME/.cache/tmux_harpoon"
data_file="$cache_dir/$tmux_cwd_hash.csv"
header="# window_id , command , file_name:r:c , file_path , workspace_dir"

declare -A window_by_index window_default_line
session_windows=()
while IFS='|' read -r window_index window_id window_command window_path; do
  window_by_index[$window_index]=$window_id
  window_default_line[$window_id]="$window_id,$window_command,::,,$window_path"
  session_windows+=("$window_id")
done < <(tmux list-windows -t "$tmux_session_id" -F '#{window_index}|#{window_id}|#{pane_current_command}|#{pane_current_path}')

entries=()
comments=()
original=""
if [[ -f $data_file ]]; then
  while IFS= read -r line || [[ -n $line ]]; do
    original+="$line"$'\n'
    if [[ -z $line ]]; then
      continue
    elif [[ $line == '# pane_id ,'* ]]; then
      comments+=("$header")
    elif [[ $line == '#'* ]]; then
      comments+=("$line")
    else
      entries+=("$line")
    fi
  done < "$data_file"
fi

pad_entries=0
if [[ ${#entries[@]} -eq 0 ]]; then
  pad_entries=1
fi
if [[ ${#comments[@]} -eq 0 ]]; then
  comments=("# session_name: $(basename "$tmux_cwd")" "$header")
fi

declare -A referenced
order=()
for i in "${!entries[@]}"; do
  entry=${entries[i]}
  if [[ $entry == *,* ]]; then
    id=${entry%%,*}
    rest=${entry#*,}
  else
    id=$entry
    rest=""
  fi

  if [[ -n $bind_line && $((i + 1)) == "$bind_line" ]]; then
    id=$bind_window
  elif [[ $id =~ ^[0-9]+$ ]]; then
    id=${window_by_index[$id]-}
  fi
  if [[ -z $id || -z ${window_default_line[$id]-} ]]; then
    id=""
  elif [[ -z ${referenced[$id]-} ]]; then
    referenced[$id]=1
    order+=("$id")
  fi

  entries[i]="$id,$rest"
done

for id in "${session_windows[@]}"; do
  if [[ -z ${referenced[$id]-} ]]; then
    entries+=("${window_default_line[$id]}")
    order+=("$id")
  fi
done

if [[ $pad_entries -eq 1 ]]; then
  while [[ ${#entries[@]} -lt 4 ]]; do
    entries+=(",bash,::,,$tmux_pane_path")
  done
fi

printf -v content '%s\n' "${entries[@]}" "${comments[@]}"
if [[ $content != "$original" ]]; then
  if [[ ! -d $cache_dir ]]; then
    mkdir -p "$cache_dir"
  fi
  printf '%s' "$content" > "$data_file.sync"
  mv "$data_file.sync" "$data_file"
fi

if [[ ${order[*]} != "${session_windows[*]}" ]]; then
  slots=("${session_windows[@]}")
  commands=()
  for position in "${!order[@]}"; do
    target=${order[position]}
    displaced=${slots[position]}
    if [[ $displaced == "$target" ]]; then
      continue
    fi
    for slot in "${!slots[@]}"; do
      if [[ ${slots[slot]} == "$target" ]]; then
        slots[slot]=$displaced
        break
      fi
    done
    slots[position]=$target
    commands+=(swap-window -d -s "$tmux_session_id:$displaced" -t "$tmux_session_id:$target" ";")
  done
  tmux "${commands[@]}" select-window -t "$tmux_session_id:$tmux_window_active"
fi
