_: {
  flake.modules.nixos.services-harmonia =
    { config, ... }:
    {
      sops.secrets.nix-serve-key = { };

      services.harmonia = {
        enable = true;
        signKeyPaths = [ config.sops.secrets.nix-serve-key.path ];
        settings.bind = "[::]:5101";
      };

      networking.firewall.allowedTCPPorts = [ 5101 ];
    };
}
