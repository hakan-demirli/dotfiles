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
          stylua
          taplo
          yamlfmt
          prettier
        ];

        settings = {
          on-unmatched = "info";
          tree-root-file = "flake.nix";

          global.excludes = [
            "flake.lock"
            ".direnv/**"
            "result"
            "result-*"
            "**/*.patch"
            "**/*.bkp"
            "**/*.dconf"
            "**/*.theme"
            "**/*.wslconfig"
            "**/*.config"
            "**/config"
            "**/*.gitignore"
            "**/*.envrc"
            "**/*.ini"
            "**/*.desktop"
            "**/*.conf"
            "**/*.ron"
            "**/*.xml"
            "modules/home/common/config/desktop_files/**"
            "modules/home/common/config/gnome3-keybind-backup/**"
            "modules/home/common/config/tmuxp/**"
          ];

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
                "modules/home/common/pkgs/bin/**"
              ];
              priority = 1;
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

            stylua = {
              command = "stylua";
              options = [
                "--indent-type"
                "Spaces"
                "--indent-width"
                "2"
              ];
              includes = [ "*.lua" ];
              priority = 1;
            };

            taplo = {
              command = "taplo";
              options = [ "fmt" ];
              includes = [ "*.toml" ];
              priority = 1;
            };

            yamlfmt = {
              command = "yamlfmt";
              includes = [
                "*.yaml"
                "*.yml"
              ];
              excludes = [
                "secrets/*.yaml"
                "secrets/*.yml"
                "secrets/**/*.yaml"
                "secrets/**/*.yml"
                "modules/home/users/*/secrets/*.yaml"
                "modules/home/users/*/secrets/*.yml"
              ];
              priority = 1;
            };

            prettier-json = {
              command = "prettier";
              options = [
                "--write"
                "--parser"
                "json"
              ];
              includes = [ "*.json" ];
              priority = 1;
            };

            prettier-css = {
              command = "prettier";
              options = [
                "--write"
                "--parser"
                "css"
              ];
              includes = [ "*.css" ];
              priority = 1;
            };

            prettier-js = {
              command = "prettier";
              options = [
                "--write"
                "--parser"
                "babel"
              ];
              includes = [ "*.js" ];
              priority = 1;
            };

            prettier-md = {
              command = "prettier";
              options = [
                "--write"
                "--parser"
                "markdown"
                "--prose-wrap"
                "preserve"
              ];
              includes = [ "*.md" ];
              priority = 1;
            };
          };
        };
      };
    };
}
