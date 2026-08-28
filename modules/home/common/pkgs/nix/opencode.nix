{
  address,
  port,
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

  serverUrl = "http://${address}:${toString port}";

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
  opencodeConfig = pkgs.linkFarm "opencode-config" opencodeConfigEntries;

  requireServerPassword = pkgs.writeShellApplication {
    name = "opencode-require-server-password";
    text = ''
      if [[ -z "''${OPENCODE_SERVER_PASSWORD:-}" ]]; then
        echo "opencode-serve: OPENCODE_SERVER_PASSWORD is unset, refusing to serve unauthenticated on ${serverUrl}" >&2
        exit 1
      fi
    '';
  };
in
{
  home = {
    packages = [ pkgs.opencode ] ++ lib.optional hasPlugins opencodePlugins;
    sessionVariables.OPENCODE_URL = serverUrl;
  };

  xdg.configFile.opencode = lib.mkIf (opencodeConfigEntries != [ ]) {
    source = opencodeConfig;
    recursive = true;
  };

  systemd.user.services.opencode-serve = {
    Unit = {
      Description = "OpenCode node server on ${serverUrl}";
      Wants = [ "sops-nix.service" ];
      After = [ "sops-nix.service" ];
      X-Restart-Triggers = [ "${opencodeConfig}" ];
    };
    Service = {
      Type = "simple";
      EnvironmentFile = serviceEnvFile;
      Environment = commonServiceEnv;
      ExecStartPre = "${requireServerPassword}/bin/opencode-require-server-password";
      ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname ${address} --port ${toString port}";
      Restart = "always";
      RestartSec = 10;
      RestartSteps = 5;
      RestartMaxDelaySec = 300;
      MemoryMax = "8G";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
