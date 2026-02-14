{
  inputs,
  lib,
  ...
}:
{
  flake.modules.nixos.services-deasciifier =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.services.deasciifier;
      deasciifierPkg = pkgs.callPackage (inputs.self + /pkgs/deasciifier.nix) { };
    in
    {
      options.services.deasciifier.port = lib.mkOption {
        type = lib.types.port;
        default = 8200;
        description = "Port to serve deasciifier on";
      };

      config = {
        systemd.services.deasciifier = {
          description = "Turkish Deasciifier Web Service";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          serviceConfig = {
            Type = "simple";
            WorkingDirectory = "${deasciifierPkg}/website";
            ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString cfg.port}";
            Restart = "always";
            DynamicUser = true;
          };
        };
      };
    };
}
