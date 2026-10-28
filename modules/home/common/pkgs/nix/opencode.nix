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
  supportedMajorVersion = "2";
  opencodePackage = unstablePkgs.opencode.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/opencode-copilot-auto.patch ];
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      bun test --cwd ../core test/github-copilot test/plugin/provider-github-copilot.test.ts
      runHook postCheck
    '';
  });

  serverUrl = "http://${address}:${toString port}";

  serviceEnvFile = "${config.home.homeDirectory}/.config/secrets/environment";
  commonServiceEnv = [
    "PATH=${config.home.homeDirectory}/.local/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
  ];

  opencodeConfigDir = ../../config/opencode;
  opencodeConfigEntries =
    if builtins.pathExists opencodeConfigDir then
      lib.mapAttrsToList (name: _type: {
        inherit name;
        path = opencodeConfigDir + "/${name}";
      }) (builtins.readDir opencodeConfigDir)
    else
      [ ];
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
  assertions = [
    {
      assertion = lib.versions.major opencodePackage.version == supportedMajorVersion;
      message = "opencode ${opencodePackage.version} is not major version ${supportedMajorVersion}. A major release breaks the plugin and server APIs, so review opencode.json and the plugins before raising supportedMajorVersion.";
    }
  ];

  home = {
    packages = [ opencodePackage ];
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
    };
    Install.WantedBy = [ "default.target" ];
  };
}
