_: {
  perSystem =
    { pkgs, ... }:
    {
      checks.statix =
        pkgs.runCommand "statix"
          {
            nativeBuildInputs = [ pkgs.statix ];
            src = pkgs.lib.fileset.toSource {
              root = ../../../..;
              fileset = pkgs.lib.fileset.fileFilter (
                file: file.hasExt "nix" || file.name == "statix.toml"
              ) ../../../..;
            };
          }
          ''
            cp -r $src ./src
            chmod -R +w ./src
            cd ./src
            echo "Running statix check ..."
            statix check .
            touch $out
          '';
    };
}
