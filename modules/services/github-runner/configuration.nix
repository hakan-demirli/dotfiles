_: {
  flake.modules.nixos.services-github-runner =
    { config, lib, ... }:
    let
      cfg = config.services.github-runner;
    in
    {
      options.services.github-runner = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable GitHub Actions self-hosted runner";
        };
        url = lib.mkOption {
          type = lib.types.str;
          default = "https://github.com/hakan-demirli";
          description = "GitHub user/organization URL";
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = "nixos-runner";
          description = "Runner name";
        };
        tokenFile = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Path to file containing GitHub runner token";
        };
      };

      config = lib.mkIf cfg.enable {
        services.github-runners.${cfg.name} = {
          enable = true;
          inherit (cfg) url;
          inherit (cfg) tokenFile;
          replace = true;
          extraLabels = [ "nixos" ];
        };

        environment.persistence."/persist".directories = [
          "/var/lib/github-runners"
        ];
      };
    };
}
