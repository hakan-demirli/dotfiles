{ inputs, lib, ... }:
let
  devicesRoot = ../devices;
  hasDevices = builtins.pathExists devicesRoot;
  discoveredDevices =
    if !hasDevices then
      { }
    else
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (devicesRoot + "/${name}/default.nix")
      ) (builtins.readDir devicesRoot);
in
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
        };
      };
      mkDevice =
        deviceId:
        import (devicesRoot + "/${deviceId}") {
          inherit pkgs system inputs;
          inherit (inputs) self;
        };
      devices = lib.mapAttrs (id: _: mkDevice id) discoveredDevices;

      flatPackages = lib.foldl' (
        acc: id:
        acc
        // (lib.mapAttrs' (name: drv: lib.nameValuePair "${id}-${name}" drv) (
          devices.${id}.packages or { }
        ))
      ) { } (lib.attrNames devices);

      flatApps = lib.foldl' (
        acc: id:
        acc
        // (lib.mapAttrs' (name: app: lib.nameValuePair "${id}-${name}" app) (devices.${id}.apps or { }))
      ) { } (lib.attrNames devices);
    in
    {
      packages = flatPackages;
      apps = flatApps;
    };

  flake.devices = lib.mapAttrs (
    id: _:
    let
      buildSystem = "x86_64-linux";
      pkgs = import inputs.nixpkgs {
        system = buildSystem;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
        };
      };
      dev = import (devicesRoot + "/${id}") {
        inherit pkgs inputs;
        system = buildSystem;
        inherit (inputs) self;
      };
    in
    {
      inherit (dev) meta lib;
    }
  ) discoveredDevices;
}
