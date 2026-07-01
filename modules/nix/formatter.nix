_: {
  perSystem =
    { pkgs, ... }:
    let
      statix-wrapper = pkgs.writeShellScriptBin "statix-fix" ''
        for path in "$@"; do
          ${pkgs.statix}/bin/statix fix "$path"
        done
      '';
    in
    {
      formatter = pkgs.treefmt.withConfig {
        runtimeInputs = with pkgs; [
          nixfmt
          deadnix
          statix
          taplo
        ];

        settings = {
          on-unmatched = "info";
          tree-root-file = "flake.nix";

          global.excludes = [
            "flake.lock"
            "secrets/**"
            ".direnv/**"
            "result"
            "result-*"
            "*.md"
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

            taplo = {
              command = "taplo";
              options = [ "fmt" ];
              includes = [ "*.toml" ];
            };
          };
        };
      };
    };
}
