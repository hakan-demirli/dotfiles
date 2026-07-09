{ pkgs, lib, ... }:
{
  options.home.portablehome = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    default = import ../pkgs/nix/portablehome.nix { inherit pkgs; };
    defaultText = lib.literalExpression "import ../pkgs/nix/portablehome.nix { inherit pkgs; }";
    description = ''
      A self-contained bundle deployable to a nix-less linux host.

      Build with:
        nix build .#homeConfigurations.<user>@<profile>.config.home.portablehome

      Then run ./result/deploy.sh user@host to push.
    '';
  };

  config = { };
}
