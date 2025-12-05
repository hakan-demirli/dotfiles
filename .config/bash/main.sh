#!/usr/bin/env bash
# shellcheck source-path=SCRIPTDIR

privateEnvFile="$HOME/.config/secrets/environment"
if [ -f "${privateEnvFile}" ] && [ -r "${privateEnvFile}" ]; then
  # shellcheck disable=SC1090
  source "${privateEnvFile}"
fi

# kitty SSH issue workaround: https://wiki.archlinux.org/title/Kitty#Terminal_issues_with_SSH
[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"

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

if [ -f "$DOTFILES_SHELL_DIR/binds.sh" ]; then
  source "$DOTFILES_SHELL_DIR/binds.sh"
fi

if [[ :$SHELLOPTS: =~ :(vi|emacs): ]]; then
  eval "$(fzf --bash)"
fi

if [[ $TERM != "dumb" ]]; then
  eval "$(starship init bash --print-full-init)"
fi

# nix-direnv?
# eval "$(direnv hook bash)"

# PROMPT_COMMAND="history -a; history -n"
# HISTCONTROL=ignoredups:erasedups
# HISTFILE="$HOME/.local/state/bash/history"
# HISTFILESIZE=-1
# HISTSIZE=-1
# mkdir -p "$(dirname "$HISTFILE")"

# shopt -s histappend
# shopt -s checkwinsize
# shopt -s extglob
# shopt -s globstar
# shopt -s checkjobs

ensure_prompt_symbol
