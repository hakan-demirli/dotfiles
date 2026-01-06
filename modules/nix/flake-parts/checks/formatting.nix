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
          }
          ''
            cp -r $src ./src
            chmod -R +w ./src
            cd ./src

            echo "Running treefmt check..."
            treefmt --ci -v

            touch $out
          '';
    };
}
