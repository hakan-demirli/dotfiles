{ inputs, lib, ... }:
let
  shellRoot = "modules/home/common/config/quickshell";

  groupedPropertyExempt = [ "shell.qml" ];
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.qmllint =
        if pkgs.stdenv.hostPlatform.isLinux then
          pkgs.runCommand "check-qmllint"
            {
              nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
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
                -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
                -I ${pkgs.quickshell}/lib/qt-6/qml
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
                qualified+=("$file")
              done

              qmllint "''${flags[@]}" --unqualified error "''${qualified[@]}"
              qmllint "''${flags[@]}" --unqualified disable ${lib.escapeShellArgs groupedPropertyExempt}

              touch $out
            ''
        else
          pkgs.runCommand "check-qmllint" { } ''
            touch $out
          '';
    };
}
