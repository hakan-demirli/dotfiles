{
  address,
  listenAddress,
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

  urlOf = host: "http://${if lib.hasInfix ":" host then "[${host}]" else host}:${toString port}";
  serverUrl = urlOf address;
  listenUrl = urlOf listenAddress;

  serviceEnvFile = "${config.home.homeDirectory}/.config/secrets/environment";
  commonServiceEnv = [
    "PATH=${config.home.homeDirectory}/.local/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
  ];

  opencodeConfigDir = ../../config/opencode;
  opencodeCliSettings = opencodeConfigDir + "/cli.json";
  proxySettings = {
    baseURL = "${(import ../../lib.nix).serviceUrl inputs "cliproxyapi"}/v1";
  }
  // lib.optionalAttrs (config.sops.secrets ? "cliproxyapi/api-key") {
    apiKey = "{file:${config.sops.secrets."cliproxyapi/api-key".path}}";
  };
  opencodeSettings = (pkgs.formats.json { }).generate "opencode.json" (
    lib.recursiveUpdate (lib.importJSON (opencodeConfigDir + "/opencode.json")) {
      providers = {
        proxy-anthropic.settings = proxySettings;
        proxy-openai.settings = proxySettings;
      };
    }
  );
  opencodeConfigEntries = lib.mapAttrsToList (name: _type: {
    inherit name;
    path = if name == "opencode.json" then opencodeSettings else opencodeConfigDir + "/${name}";
  }) (removeAttrs (builtins.readDir opencodeConfigDir) [ "cli.json" ]);
  opencodeConfig = pkgs.linkFarm "opencode-config" opencodeConfigEntries;

  requireServerPassword = pkgs.writeShellApplication {
    name = "opencode-require-server-password";
    text = ''
      if [[ -z "''${OPENCODE_SERVER_PASSWORD:-}" ]]; then
        echo "opencode-serve: OPENCODE_SERVER_PASSWORD is unset, refusing to serve unauthenticated on ${listenUrl}" >&2
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

    activation.configureOpencodeCli = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -d -m 700 ${lib.escapeShellArg "${config.xdg.configHome}/opencode"}
      if [[ ! -v DRY_RUN ]]; then
        settings=${lib.escapeShellArg "${config.xdg.configHome}/opencode/cli.json"}
        previous="$settings"
        if [[ ! -f "$previous" ]]; then
          previous=${pkgs.writeText "opencode-empty-cli.json" "{}"}
        fi
        next="$(mktemp "$settings.XXXXXX")"
        if ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$previous" ${opencodeCliSettings} > "$next"; then
          chmod 600 "$next"
          mv -f "$next" "$settings"
        else
          rm -f "$next"
          exit 1
        fi
      fi
    '';
  };

  xdg.configFile.opencode = lib.mkIf (opencodeConfigEntries != [ ]) {
    source = opencodeConfig;
    recursive = true;
  };

  systemd.user.services.opencode-serve = lib.mkIf ((import ../../lib.nix).allowsPersonalData facts) {
    Unit = {
      Description = "OpenCode node server on ${listenUrl}";
      Wants = [ "sops-nix.service" ];
      After = [ "sops-nix.service" ];
      X-Restart-Triggers = [ "${opencodeConfig}" ];
    };
    Service = {
      Type = "simple";
      EnvironmentFile = serviceEnvFile;
      Environment = commonServiceEnv;
      ExecStartPre = "${requireServerPassword}/bin/opencode-require-server-password";
      ExecStart = "${opencodePackage}/bin/opencode serve --hostname ${listenAddress} --port ${toString port}";
      Restart = "always";
      RestartSec = 10;
      RestartSteps = 5;
      RestartMaxDelaySec = 300;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
