#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

DOTFILES_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

if [ -f "$DOTFILES_SHELL_DIR/exports.sh" ]; then
  source "$DOTFILES_SHELL_DIR/exports.sh"
fi

if [ -f "$DOTFILES_SHELL_DIR/aliases.sh" ]; then
  source "$DOTFILES_SHELL_DIR/aliases.sh"
fi

if [ -f "$DOTFILES_SHELL_DIR/functions.sh" ]; then
  source "$DOTFILES_SHELL_DIR/functions.sh"
fi
