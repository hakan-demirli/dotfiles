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
      officeBin = "${opencodePlugins.opencode-office}/bin/opencode-office";

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
        enable = lib.mkEnableOption "OpenCode shared HTTP serve and global office daemon" // {
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

        office = {
          enable = lib.mkEnableOption "global office daemon (judge supervisor)" // {
            default = true;
          };
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

        systemd.user.services.opencode-office-daemon = lib.mkIf cfg.office.enable {
          Unit = {
            Description = "OpenCode office daemon (judge supervisor)";
            After = [ "opencode-serve.service" ];
            Requires = [ "opencode-serve.service" ];
          };
          Service = {
            Type = "simple";
            EnvironmentFile = serviceEnvFile;
            Environment = commonServiceEnv ++ [
              "OPENCODE_URL=http://${cfg.hostname}:${toString cfg.port}"
            ];
            ExecStart = "${officeBin} daemon-run";
            Restart = "on-failure";
            RestartSec = 2;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
}
