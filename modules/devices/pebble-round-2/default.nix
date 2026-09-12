{
  pkgs,
  self,
  ...
}:
let
  facts = self.lib.inventory.hosts.pebble-round-2;

  pebbleosSource = pkgs.callPackage ./nix/pebbleos-source.nix { };
  pebbleosSdk = pkgs.callPackage ./nix/pebbleos-sdk.nix {
    sdkVersion = facts.labels.pebbleos_sdk_version;
  };

  firmware = pkgs.callPackage ./nix/firmware.nix {
    inherit pebbleosSource pebbleosSdk;
    board = "${facts.labels.board}@${facts.labels.board_revision}";
    variant = "normal";
    releaseBuild = false;
  };

  firmware-release = pkgs.callPackage ./nix/firmware.nix {
    inherit pebbleosSource pebbleosSdk;
    board = "${facts.labels.board}@${facts.labels.board_revision}";
    variant = "normal";
    releaseBuild = true;
  };

  firmware-prf = pkgs.callPackage ./nix/firmware.nix {
    inherit pebbleosSource pebbleosSdk;
    board = "${facts.labels.board}@${facts.labels.board_revision}";
    variant = "prf";
    releaseBuild = false;
  };

  appSdk = pkgs.callPackage ./nix/app-sdk.nix {
    inherit pebbleosSource pebbleosSdk;
    board = "${facts.labels.board}@${facts.labels.board_revision}";
    inherit (facts.labels) platform;
  };

  orbit = pkgs.callPackage ./nix/watchface.nix {
    inherit appSdk pebbleosSdk;
    src = ./watchface;
  };
in
{
  packages = {
    inherit
      firmware
      firmware-release
      firmware-prf
      orbit
      ;
    app-sdk = appSdk;
    pebbleos-sdk = pebbleosSdk;
    pebbleos-source = pebbleosSource;
  };

  lib = { };

  meta = {
    kind = facts.hardware.os;
    hardware = facts.hardware.chassis;
    hardware_soc = facts.hardware.cpu_model;
    needsRelaxedSandbox = true;
    board = facts.labels.board;
    board_revision = facts.labels.board_revision;
    platform = facts.labels.platform;
    pebbleos_version = facts.labels.pebbleos_version;
    pebbleos_sdk_version = facts.labels.pebbleos_sdk_version;
    connectivity = facts.labels.connectivity;
  };
}
