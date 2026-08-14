#!/usr/bin/env bash
set -euo pipefail

exec device-lock-toggle.sh tablet "$@"
