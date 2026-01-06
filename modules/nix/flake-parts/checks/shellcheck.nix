{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.shellcheck =
        pkgs.runCommand "shellcheck-all"
          {
            nativeBuildInputs = [ pkgs.shellcheck ];
            src = inputs.self;
          }
          ''
            cp -r $src ./src
            chmod -R +w ./src
            cd ./src

            find . -type f \( -name "*.sh" -o -name "*.bash" \) -not -path "./.git/*" > scripts.txt

            find . -type f -not -path "./.git/*" -exec sh -c '
                head -n1 "$1" 2>/dev/null | grep -Eq "^#!/usr/bin/env[[:space:]]+bash$"
            ' _ {} \; >> scripts.txt

            sort -u scripts.txt -o scripts.txt

            if [ ! -s scripts.txt ]; then
                echo "No shell scripts found to check."
            else
                echo "Running shellcheck on:"
                cat scripts.txt
                xargs -a scripts.txt shellcheck --
            fi

            touch $out
          '';
    };
}
