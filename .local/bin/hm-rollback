#!/usr/bin/env bash
set -euo pipefail

selected_gen=$(home-manager generations | fzf | awk -F '-> ' '{print $2 "/activate"}') || exit
bash "$selected_gen"
