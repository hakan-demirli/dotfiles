{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks.statix =
        pkgs.runCommand "statix"
          {
            nativeBuildInputs = [ pkgs.statix ];
            src = inputs.self;
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
