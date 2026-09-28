#!/usr/bin/env bash
set -euo pipefail

format=$(tmux show-option -gv 'status-format[0]')
badge='#[align=centre]#[bg=#215a64,fg=#f8f8f2,bold] #{host_short} #[default]'

if [[ $format != *"$badge"* ]]; then
  tmux set-option -ga 'status-format[0]' "$badge"
fi
