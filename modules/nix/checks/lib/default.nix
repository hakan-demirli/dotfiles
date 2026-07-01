{
  pkgs,
  self,
  lib,
  ...
}:
{
  codegen-smoke = import ./codegen-smoke.nix { inherit pkgs self; };
  intent = import ./intent.nix { inherit pkgs self; };
  inventory-eval = import ./inventory-eval.nix { inherit pkgs self lib; };
}
