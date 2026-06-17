{
  inputs,
  ...
}:
{
  flake.modules.homeManager.services-opencode =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.opencode;
      nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };
      opencodePlugins = nurPkgs.opencode-plugins;

      serviceEnvFile = "${config.home.homeDirectory}/.config/secrets/environment";
      commonServiceEnv = [
        "PATH=${config.home.homeDirectory}/.local/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];

      opencodeConfigEntries =
        let
          opencodeConfigDir = ../../../.config/opencode;
          dotfileEntries = pkgs.lib.mapAttrsToList (name: _type: {
            inherit name;
            path = opencodeConfigDir + "/${name}";
          }) (builtins.removeAttrs (builtins.readDir opencodeConfigDir) [ "plugins" ]);
          pluginEntries = [
            {
              name = "plugins";
              path = "${opencodePlugins}/plugins";
            }
          ];
        in
        dotfileEntries ++ pluginEntries;
    in
    {
      options.services.opencode = {
        enable = lib.mkEnableOption "OpenCode shared HTTP serve" // {
          default = true;
        };

        hostname = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = ''
            Hostname the shared ``opencode serve`` binds to. Loopback by
            default; do not expose to a network without setting up auth.
          '';
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 4096;
          description = "Port the shared ``opencode serve`` binds to.";
        };
      };

      config = lib.mkIf cfg.enable {
        home.packages = [
          pkgs.opencode
          opencodePlugins
        ];

        xdg.configFile.opencode = {
          source = pkgs.linkFarm "opencode-config" opencodeConfigEntries;
          recursive = true;
        };

        systemd.user.services.opencode-serve = {
          Unit = {
            Description = "OpenCode shared HTTP server";
            After = [
              "network.target"
              "default.target"
            ];
          };
          Service = {
            Type = "simple";
            EnvironmentFile = serviceEnvFile;
            Environment = commonServiceEnv;
            ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname ${cfg.hostname} --port ${toString cfg.port}";
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
