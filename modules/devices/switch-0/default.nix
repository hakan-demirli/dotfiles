{
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;
  model = import ./model/gwn7721.nix;
  desired = import ./desired { inherit lib model; };

  desiredJson = pkgs.writeText "switch-0-desired.json" (builtins.toJSON desired);
  scripts = ./nix;

  environment = ''
    export SWITCH_0_ADDRESS="''${SWITCH_0_ADDRESS:-${desired.management.address}}"
    export SWITCH_0_PORT="${toString model.api.port}"
    export SWITCH_0_USERNAME="${desired.management.username}"
    export SWITCH_0_MODEL="${model.model}"
    export SWITCH_0_FIRMWARE="${desired.firmwareVersion}"
    export SWITCH_0_DESIRED="${desiredJson}"
  '';

  runtimeInputs = [
    pkgs.openssh
    pkgs.python3
    pkgs.sops
  ];

  capture = pkgs.writeShellApplication {
    name = "switch-0-capture";
    inherit runtimeInputs;
    text = environment + ''
      exec python3 ${scripts}/capture.py "$@"
    '';
  };

  config = pkgs.writeShellApplication {
    name = "switch-0-config";
    inherit runtimeInputs;
    text = environment + ''
      exec python3 ${scripts}/reconcile.py "$@"
    '';
  };
in
{
  packages = {
    inherit capture config;
    desired = desiredJson;
  };

  apps = {
    capture = {
      type = "app";
      program = "${capture}/bin/switch-0-capture";
      meta.description = "Capture switch-0 device state into an encrypted baseline";
    };
    config = {
      type = "app";
      program = "${config}/bin/switch-0-config";
      meta.description = "Compare switch-0 against its declared state";
    };
  };

  lib = {
    inherit model desired;
  };

  meta = {
    kind = "vendor-firmware";
    hardware = model.model;
    firmware_version = desired.firmwareVersion;
    lan_ip = desired.management.address;
    management_scheme = model.api.scheme;
  };
}
