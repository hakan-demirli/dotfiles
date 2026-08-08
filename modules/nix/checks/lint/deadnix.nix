{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.deadnix =
        pkgs.runCommand "deadnix"
          {
            nativeBuildInputs = [ pkgs.deadnix ];
            src = inputs.self;
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
