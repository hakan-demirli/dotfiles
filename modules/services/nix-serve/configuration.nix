_: {
  flake.modules.nixos.services-nix-serve =
    { config, pkgs, ... }:
    {
      services.nix-serve = {
        enable = true;
        package = pkgs.nix-serve-ng;
        secretKeyFile = config.sops.secrets.nix-serve-key.path;
        openFirewall = true;
        port = 5101;
      };
    };
}
