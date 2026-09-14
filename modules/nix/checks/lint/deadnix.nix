_: {
  perSystem =
    { pkgs, ... }:
    {
      checks.deadnix =
        pkgs.runCommand "deadnix"
          {
            nativeBuildInputs = [ pkgs.deadnix ];
            src = pkgs.lib.fileset.toSource {
              root = ../../../..;
              fileset = pkgs.lib.fileset.fileFilter (file: file.hasExt "nix") ../../../..;
            };
          }
          ''
            cp -r $src ./src
            chmod -R +w ./src
            cd ./src
            echo "Running deadnix --fail ..."
            deadnix --fail .
            touch $out
          '';
    };
}
