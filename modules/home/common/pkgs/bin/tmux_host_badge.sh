#!/usr/bin/env bash
set -euo pipefail

badge='#[align=absolute-centre]#[bg=#215a64,fg=#f8f8f2,bold] #{host_short} #[default]'

tmux set-option -gu status-format \; set-option -ga 'status-format[0]' "$badge"
