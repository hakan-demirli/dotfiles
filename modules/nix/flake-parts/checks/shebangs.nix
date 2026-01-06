{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.shebangs =
        pkgs.runCommand "check-shebangs"
          {
            src = inputs.self;
          }
          ''
            cp -r $src ./src
            chmod -R +w ./src
            cd ./src

            failed=0

            echo "Checking for absolute bash paths..."
            while IFS= read -r -d "" file; do
                if head -n1 "$file" 2> /dev/null | grep -Eq '^#!/(bin/|usr/bin/)bash([[:space:]]|$)'; then
                    echo "ERROR: Absolute path shebang found in: $file"
                    head -n1 "$file"
                    failed=1
                fi
            done < <(find . -type f -not -path "./.git/*" -print0)

            echo "Checking for absolute python paths..."
            while IFS= read -r -d "" file; do
                if head -n1 "$file" 2> /dev/null | grep -Eq '^#!/(bin/|usr/bin/)python[3]?([[:space:]]|$)'; then
                    echo "ERROR: Absolute python path shebang found in: $file"
                    head -n1 "$file"
                    failed=1
                fi
            done < <(find . -type f -not -path "./.git/*" -print0)

            if [ "$failed" -eq 1 ]; then
                echo "Shebang check failed. Use /usr/bin/env instead of absolute paths."
                exit 1
            fi

            touch $out
          '';
    };
}
