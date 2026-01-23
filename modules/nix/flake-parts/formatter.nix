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
              command = "shfmt";
              options = [
                "-i"
                "2"
                "-ln"
                "bash"
                "-s"
                "-ci"
                "-bn"
                "-sr"
                "-w"
              ];
              includes = [
                "*.sh"
                "*.bash"
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
