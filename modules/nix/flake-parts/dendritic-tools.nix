{
  inputs,
  ...
}:
{
  # setup of tools for dendritic pattern

  # Simplify Nix Flakes with the module system
  # https://github.com/hercules-ci/flake-parts

  # Generate flake.nix from module options.
  # https://github.com/vic/flake-file

  # Import all nix files in a directory tree.
  # https://github.com/vic/import-tree

  imports = [
    inputs.flake-parts.flakeModules.modules
  ];

  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];
}
