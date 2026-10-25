{ inputs, lib, ... }:
let
  shellRoot = "modules/home/common/config/quickshell";

  groupedPropertyExempt = [ "shell.qml" ];
in
{
  perSystem =
    { pkgs, system, ... }:
    let
      qmlPkgs = inputs.nixpkgs-qmllint.legacyPackages.${system};
    in
    {
      checks.qmllint =
        if pkgs.stdenv.hostPlatform.isLinux then
          pkgs.runCommand "check-qmllint"
            {
              nativeBuildInputs = [ qmlPkgs.qt6.qtdeclarative ];
              src = inputs.self;
              LANG = "C.UTF-8";
            }
            ''
              if find "$src" -name '*.qml' -not -path "$src/${shellRoot}/*" | grep .; then
                echo "check-qmllint: the QML above lives outside ${shellRoot} and is unchecked." >&2
                exit 1
              fi

              cp -r "$src/${shellRoot}" ./shell
              chmod -R +w ./shell
              cd ./shell

              for file in *.qml; do
                if grep -qx 'pragma Singleton' "$file"; then
                  echo "singleton ''${file%.qml} 1.0 $file"
                fi
              done > qmldir

              flags=(
                --ignore-settings
                --bare
                --max-warnings 0
                -I ${qmlPkgs.qt6.qtdeclarative}/lib/qt-6/qml
                -I ${qmlPkgs.quickshell}/lib/qt-6/qml
                --unused-imports error
                --unresolved-type disable
                --uncreatable-type disable
                --signal-handler-parameters disable
              )

              qualified=()
              for file in *.qml; do
                case "$file" in
                  ${lib.concatStringsSep " | " groupedPropertyExempt}) continue ;;
                esac
                qualified+=("$PWD/$file")
              done
              exempt=(${lib.escapeShellArgs groupedPropertyExempt})

              qmllint "''${flags[@]}" --unqualified error "''${qualified[@]}"
              qmllint "''${flags[@]}" --unqualified disable "''${exempt[@]/#/$PWD/}"

              touch $out
            ''
        else
          pkgs.runCommand "check-qmllint" { } ''
            touch $out
          '';
    };
}
