#!/usr/bin/env bash

privateEnvFile="$HOME/Desktop/dotfiles/secrets/environment"
if [ -f "${privateEnvFile}" ] && [[ "$(file -b --mime-type "${privateEnvFile}")" == "text/plain" ]]; then
  # shellcheck disable=SC1090
  source "${privateEnvFile}"
fi

lf_cd() {
  if command -v lf &>/dev/null; then
    cd "$(command lf -print-last-dir "$@")" || exit
  else
    echo "Command 'lf' not found. Please install it."
  fi
}

yazi_cd() {
  if ! command -v yazi &>/dev/null; then
    echo "Command 'yazi' not found. Please install it."
    return 1
  fi

  tmp="$(mktemp -t "yazi-cwd.XXXXX")"

  trap 'rm -f -- "$tmp"' EXIT

  yazi --cwd-file="$tmp"

  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd -- "$cwd" || exit
  fi
}

gcmp() {
  if [ -z "$1" ]; then
    echo "Usage: gcmp \"Your commit message\""
    return 1
  fi
  git commit -m "$1" && git push
}

if command -v wl-copy &>/dev/null; then
  _copy_readline_to_clipboard() {
    echo -n "$READLINE_LINE" | wl-copy
  }
  bind -x '"\C-y": _copy_readline_to_clipboard'
fi

# kitty SSH issue workaround: https://wiki.archlinux.org/title/Kitty#Terminal_issues_with_SSH
[ "$TERM" = "xterm-kitty" ] && alias ssh="kitty +kitten ssh"
