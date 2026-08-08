{ pkgs }:
pkgs.writeShellApplication {
  name = "send-to-laptop";
  runtimeInputs = [ pkgs.rsync ];
  text = ''
    if (( $# == 0 )); then
      echo "usage: send-to-laptop FILE..." >&2
      exit 2
    fi

    exec rsync \
      --ipv4 \
      --recursive \
      --links \
      --times \
      --human-readable \
      --partial-dir=.rsync-partial \
      --info=progress2 \
      --ignore-existing \
      --safe-links \
      -- \
      "$@" \
      rsync://laptop-1.ts.sshr.polarbearvuzi.com/inbox/
  '';
}
