{
  pkgs,
  self,
  lib,
  inputs,
  ...
}:
{
  bootstrap-authentication = import ./bootstrap-authentication.nix { inherit pkgs self inputs; };
  bootstrap-secrets = import ./bootstrap-secrets.nix { inherit pkgs self lib; };
  codegen-smoke = import ./codegen-smoke.nix { inherit pkgs self inputs; };
  device-lock-cli = import ./device-lock-cli.nix { inherit pkgs self; };
  generated-headscale-policy = import ./generated-headscale-policy.nix {
    inherit pkgs self inputs;
  };
  file-transfer = import ./file-transfer.nix { inherit pkgs self lib; };
  intent = import ./intent.nix { inherit pkgs self; };
  inventory-eval = import ./inventory-eval.nix { inherit pkgs self lib; };
  installers = import ./installers.nix { inherit pkgs self; };
  home-profile-policy = import ./home-profile-policy.nix {
    inherit
      inputs
      lib
      pkgs
      self
      ;
  };
  home-storage-policy = import ./home-storage-policy.nix { inherit pkgs self lib; };
  remote-desktop-cli = import ./remote-desktop-cli.nix { inherit pkgs self; };
  ssh-targets = import ./ssh-targets.nix { inherit pkgs self; };
}
