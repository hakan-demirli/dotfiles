#!/usr/bin/env bash

lf_cd() {
  if command -v lf &> /dev/null; then
    cd "$(command lf -print-last-dir "$@")" || exit
  else
    echo "Command 'lf' not found. Please install it."
  fi
}

yazi_cd() {
  if ! command -v yazi &> /dev/null; then
    echo "Command 'yazi' not found. Please install it."
    return 1
  fi

  mkdir -p "$TMPDIR" 2> /dev/null
  tmp="$(mktemp -t "yazi-cwd.XXXXX")"

  yazi --cwd-file="$tmp"

  if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    cd -- "$cwd" || exit
  fi

  rm -f -- "$tmp"
}

gcmp() {
  if [ -z "$1" ]; then
    echo 'Usage: gcmp "Your commit message"'
    return 1
  fi
  git commit -m "$1" && git push
}

_copy_readline_to_clipboard_local() {
  echo -n "$READLINE_LINE" | wl-copy
}

_copy_readline_to_clipboard_remote() {
  printf '\e]52;c;%s\a' "$(echo -n "$READLINE_LINE" | base64 -w0)"
}

ensure_prompt_symbol() {
  if [[ $PS1 != *❯* ]]; then
    PS1="${PS1}\n❯ "
  fi
}
