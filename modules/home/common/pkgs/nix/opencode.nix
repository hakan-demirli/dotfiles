{
  hostname ? "127.0.0.1",
  port ? 4096,
}:
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };
  opencodePlugins = nurPkgs.opencode-plugins or null;
  hasPlugins = opencodePlugins != null;

  serviceEnvFile = "${config.home.homeDirectory}/.config/secrets/environment";
  commonServiceEnv = [
    "PATH=${config.home.homeDirectory}/.local/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
  ];

  opencodeConfigDir = ../../config/opencode;
  dotfileEntries =
    if builtins.pathExists opencodeConfigDir then
      lib.mapAttrsToList (name: _type: {
        inherit name;
        path = opencodeConfigDir + "/${name}";
      }) (builtins.removeAttrs (builtins.readDir opencodeConfigDir) [ "plugins" ])
    else
      [ ];
  pluginEntries = lib.optional hasPlugins {
    name = "plugins";
    path = "${opencodePlugins}/plugins";
  };
  opencodeConfigEntries = dotfileEntries ++ pluginEntries;
in
{
  home.packages = [ pkgs.opencode ] ++ lib.optional hasPlugins opencodePlugins;

  xdg.configFile.opencode = lib.mkIf (opencodeConfigEntries != [ ]) {
    source = pkgs.linkFarm "opencode-config" opencodeConfigEntries;
    recursive = true;
  };

  systemd.user.services.opencode-serve = {
    Unit = {
      Description = "OpenCode shared HTTP server";
      After = [ "network.target" ];
    };
    Service = {
      Type = "simple";
      EnvironmentFile = "-${serviceEnvFile}";
      Environment = commonServiceEnv;
      ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname ${hostname} --port ${toString port}";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
