{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.home-boundary =
        pkgs.runCommand "check-home-boundary"
          {
            nativeBuildInputs = [ pkgs.ripgrep ];
            src = inputs.self;
          }
          ''
            home="$src/modules/home"
            failed=0

            if rg -n '(^|[;&|[:space:]])(sudo|doas|pkexec)([[:space:]]|$)|/run/wrappers/' \
              "$home"; then
              echo "Home code must not perform privilege escalation." >&2
              failed=1
            fi

            if rg -n '(\.\./)+home/|modules/home/' \
              "$src/modules/system" \
              "$src/modules/services" \
              "$src/modules/hardware" \
              "$src/modules/hosts" \
              "$src/modules/deployment-roles" \
              --glob '*.nix'; then
              echo "System/admin modules must not import implementations from modules/home." >&2
              failed=1
            fi

            if [ "$failed" -ne 0 ]; then
              exit 1
            fi

            touch "$out"
          '';
    };
}
