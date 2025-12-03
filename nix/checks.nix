{ pkgs }:

{
  deadnix = (import ./checks/deadnix.nix { inherit pkgs; }).lint;
  statix = (import ./checks/statix.nix { inherit pkgs; }).lint;
  shebangs = (import ./checks/shebangs.nix { inherit pkgs; }).check;
  formatting = (import ./checks/formatting.nix { inherit pkgs; }).fmt;
  shellcheck = (import ./checks/shellcheck.nix { inherit pkgs; }).lint;
}
