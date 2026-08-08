{ inputs, ... }:
let
  homeLibFile = ../home/common/lib.nix;
  homeRoot = ../home/users;
in
{
  flake.homeConfigurations =
    if !builtins.pathExists homeLibFile then
      { }
    else
      (import homeLibFile).mkHomeConfigurations { inherit inputs homeRoot; };
}
