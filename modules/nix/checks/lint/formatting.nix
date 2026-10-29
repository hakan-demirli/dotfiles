{ inputs, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      checks.formatting =
        pkgs.runCommand "check-formatting"
          {
            nativeBuildInputs = [ config.formatter ];
            src = inputs.self;
            passthru.ciScope = "portable";
          }
          ''
            cp -r $src ./src
            chmod -R +w ./src
            cd ./src

            echo "Running treefmt --ci ..."
            treefmt --ci -v

            touch $out
          '';
    };
}
