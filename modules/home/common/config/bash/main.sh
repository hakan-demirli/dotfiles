#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

privateEnvFile="$HOME/.config/secrets/environment"
if [ -f "${privateEnvFile}" ] && [ -r "${privateEnvFile}" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${privateEnvFile}"
  set +a
fi

privateBinDir="$HOME/.local/bin/private"
if [ -d "$privateBinDir" ]; then
  export PATH="$privateBinDir:$PATH"
fi

[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

DOTFILES_SHELL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

if [ -f "$DOTFILES_SHELL_DIR/exports.sh" ]; then
  # shellcheck source=./exports.sh
  source "$DOTFILES_SHELL_DIR/exports.sh"
fi

if [ -f "$DOTFILES_SHELL_DIR/aliases.sh" ]; then
  # shellcheck source=./aliases.sh
  source "$DOTFILES_SHELL_DIR/aliases.sh"
fi

if [ -f "$DOTFILES_SHELL_DIR/functions.sh" ]; then
  # shellcheck source=./functions.sh
  source "$DOTFILES_SHELL_DIR/functions.sh"
fi

if [ -f "$DOTFILES_SHELL_DIR/binds.sh" ]; then
  # shellcheck source=./binds.sh
  source "$DOTFILES_SHELL_DIR/binds.sh"
fi

if [[ :$SHELLOPTS: =~ :(vi|emacs): ]]; then
  eval "$(fzf --bash)"
fi

if [[ $TERM != "dumb" ]]; then
  eval "$(starship init bash --print-full-init)"
fi

ensure_prompt_symbol
