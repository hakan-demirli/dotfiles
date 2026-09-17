{
  address,
  port,
}:
{
  config,
  lib,
  pkgs,
  inputs,
  facts,
  ...
}:
let
  unstablePkgs = (import ../../lib.nix).mkUnstablePkgs { inherit inputs pkgs; };
  nurPkgs = inputs.nur.packages.${pkgs.stdenv.hostPlatform.system} or { };
  basePlugins = nurPkgs.opencode-plugins or null;
  hasPlugins = basePlugins != null;
  opencodePlugins = lib.mapNullable (
    plugins: plugins.override { inherit (unstablePkgs) claude-code; }
  ) basePlugins;
  opencodePackage = unstablePkgs.opencode.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      (pkgs.fetchurl {
        url = "https://github.com/anomalyco/opencode/commit/7f392ba6178ac1be6f2b6385293a61586cd98a87.patch";
        hash = "sha256-AnG+asHaWzDp9HpeviX5QrAWzGq5/vGjp3djm6en8Eo=";
      })
      (pkgs.fetchurl {
        url = "https://github.com/anomalyco/opencode/commit/98639ab00182513cc614461f6037d686a82489ec.patch";
        hash = "sha256-d6Vo8zvp9zyoVyvaDnuakvYivnIZhE5r3LpPhrPyyg4=";
      })
    ];
  });

  serverUrl = "http://${address}:${toString port}";

  serviceEnvFile = "${config.home.homeDirectory}/.config/secrets/environment";
  commonServiceEnv = [
    "PATH=${config.home.homeDirectory}/.local/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
  ];

  opencodeConfigDir = ../../config/opencode;
  localPluginsDir = opencodeConfigDir + "/plugins";
  dotfileEntries =
    if builtins.pathExists opencodeConfigDir then
      lib.mapAttrsToList (name: _type: {
        inherit name;
        path = opencodeConfigDir + "/${name}";
      }) (builtins.removeAttrs (builtins.readDir opencodeConfigDir) [ "plugins" ])
    else
      [ ];
  mergedPlugins = pkgs.symlinkJoin {
    name = "opencode-plugins";
    paths =
      lib.optional hasPlugins "${opencodePlugins}/plugins"
      ++ lib.optional (builtins.pathExists localPluginsDir) localPluginsDir;
  };
  pluginEntries = lib.optional (hasPlugins || builtins.pathExists localPluginsDir) {
    name = "plugins";
    path = mergedPlugins;
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
    packages = [ opencodePackage ] ++ lib.optional hasPlugins opencodePlugins;
    sessionVariables = lib.optionalAttrs ((import ../../lib.nix).allowsPersonalData facts) {
      OPENCODE_URL = serverUrl;
    };
  };

  xdg.configFile.opencode = lib.mkIf (opencodeConfigEntries != [ ]) {
    source = opencodeConfig;
    recursive = true;
  };

  systemd.user.services.opencode-serve = lib.mkIf ((import ../../lib.nix).allowsPersonalData facts) {
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
      ExecStart = "${opencodePackage}/bin/opencode serve --hostname ${address} --port ${toString port}";
      Restart = "always";
      RestartSec = 10;
      RestartSteps = 5;
      RestartMaxDelaySec = 300;
      MemoryMax = "8G";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
