{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.portable-bin =
        pkgs.runCommand "check-portable-bin"
          {
            nativeBuildInputs = [ pkgs.ripgrep ];
            src = inputs.self;
          }
          ''
            bin="$src/modules/home/common/pkgs/bin"
            failed=0

            if rg -n '/run/current-system/|/run/wrappers/|/nix/store/' "$bin"; then
              echo "Portable bin sources contain NixOS-specific executable paths." >&2
              failed=1
            fi

            if rg -n '^#!/usr/bin/env python([[:space:]]|$)' "$bin"; then
              echo "Portable Python scripts must request python3." >&2
              failed=1
            fi

            while IFS= read -r file; do
              case "$file" in
                *.sh) ;;
                *)
                  echo "Portable shell script must use a .sh extension: $file" >&2
                  failed=1
                  ;;
              esac
            done < <(rg -l '^#!/usr/bin/env bash' "$bin")

            if [ "$failed" -ne 0 ]; then
              exit 1
            fi

            touch "$out"
          '';
    };
}
