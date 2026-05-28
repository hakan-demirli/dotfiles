_: {
  perSystem =
    { pkgs, ... }:
    let
      statix-wrapper = pkgs.writeShellScriptBin "statix-fix" ''
        for path in "$@"; do
          ${pkgs.statix}/bin/statix fix "$path"
        done
      '';

      shfmt-wrapper = pkgs.writeShellApplication {
        name = "shfmt-shell-only";
        runtimeInputs = [ pkgs.shfmt ];
        text = ''
          for f in "$@"; do
            case "$f" in
              *.sh | *.bash) ;;
              *)
                if ! head -n1 "$f" 2> /dev/null \
                  | grep -Eq '^#!(/usr/bin/env[[:space:]]+(bash|sh)|/bin/(ba)?sh)([[:space:]]|$)'; then
                  continue
                fi
                ;;
            esac
            shfmt -i 2 -ln bash -s -ci -bn -sr -w "$f"
          done
        '';
      };
    in
    {
      formatter = pkgs.treefmt.withConfig {
        runtimeInputs = with pkgs; [
          nixfmt
          deadnix
          statix
          shfmt
          ruff
        ];

        settings = {
          on-unmatched = "info";
          tree-root-file = "flake.nix";

          formatter = {
            deadnix = {
              command = "deadnix";
              options = [ "--edit" ];
              includes = [ "*.nix" ];
              priority = 1;
            };

            statix = {
              command = "${statix-wrapper}/bin/statix-fix";
              includes = [ "*.nix" ];
              priority = 2;
            };

            nixfmt = {
              command = "nixfmt";
              includes = [ "*.nix" ];
              priority = 3;
            };

            shfmt = {
              command = "${shfmt-wrapper}/bin/shfmt-shell-only";
              includes = [
                "*.sh"
                "*.bash"
                ".local/bin/**"
                ".config/lf/**"
              ];
            };

            ruff-check = {
              command = "ruff";
              options = [
                "check"
                "--fix"
                "--select"
                "E,W,F,I,B,C4,UP,SIM,RUF"
                "--ignore"
                "E501,W191,E111,E114,E117"
              ];
              includes = [ "*.py" ];
              priority = 1;
            };

            ruff-format = {
              command = "ruff";
              options = [ "format" ];
              includes = [ "*.py" ];
              priority = 2;
            };
          };
        };
      };
    };
}
