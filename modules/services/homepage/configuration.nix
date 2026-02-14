{
  inputs,
  lib,
  ...
}:
{
  flake.modules.nixos.services-homepage =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.services.homepage;
      ts = "100.64.0.1";

      services = [
        {
          name = "ntfy";
          url = "http://${ts}:8111";
        }
        {
          name = "Deasciifier";
          url = "http://${ts}:8200";
        }
        {
          name = "Jellyfin";
          url = "http://${ts}:8096";
        }
      ]
      ++ cfg.extraServices;

      addresses = [
        {
          name = "Headscale";
          url = "https://${config.services.headscale-server.serverUrl}";
        }
        {
          name = "Nix Cache";
          url = "http://${ts}:5101";
        }
        {
          name = "Docker Registry";
          url = "http://${ts}:5000";
        }
      ]
      ++ cfg.extraAddresses;

      configJson = pkgs.writeText "homepage-config.json" (
        builtins.toJSON { inherit services addresses; }
      );

      nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system};
      homepagePkg = nurPkgs.homepage.override { configFile = configJson; };
    in
    {
      options.services.homepage = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 8100;
        };

        extraServices = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption { type = lib.types.str; };
                url = lib.mkOption { type = lib.types.str; };
              };
            }
          );
          default = [ ];
        };

        extraAddresses = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption { type = lib.types.str; };
                url = lib.mkOption { type = lib.types.str; };
              };
            }
          );
          default = [ ];
        };
      };

      config.services.caddy = {
        enable = true;
        virtualHosts.":${toString cfg.port}".extraConfig = ''
          root * ${homepagePkg}/share/homepage
          file_server
        '';
      };
    };
}
