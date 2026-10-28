{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  unstablePkgs = (import ../../lib.nix).mkUnstablePkgs { inherit inputs pkgs; };
  cfg = config.programs.pi-coding-agent;
  stateDir = "${config.xdg.stateHome}/pi";
  cacheDir = "${config.xdg.cacheHome}/pi";
  settings = (pkgs.formats.json { }).generate "pi-settings.json" cfg.settings;
  proxyUrl = (import ../../lib.nix).serviceUrl inputs "cliproxyapi";
  proxyApiKey = lib.optionalAttrs (config.sops.secrets ? "cliproxyapi/api-key") {
    apiKey = "!cat ${config.sops.secrets."cliproxyapi/api-key".path}";
  };
  models = (pkgs.formats.json { }).generate "models.json" (
    lib.recursiveUpdate (lib.importJSON ../../config/pi/models.json) {
      providers = {
        proxy-anthropic = proxyApiKey // {
          baseUrl = proxyUrl;
        };
        proxy-openai = proxyApiKey // {
          baseUrl = "${proxyUrl}/v1";
        };
      };
    }
  );
  piConfig = pkgs.runCommand "pi-config" { } ''
    cp -r ${../../config/pi} $out
    chmod -R u+w $out
    cp ${models} $out/models.json
  '';
  pi = pkgs.symlinkJoin {
    name = "pi-coding-agent-${unstablePkgs.pi-coding-agent.version}";
    inherit (unstablePkgs.pi-coding-agent) meta;
    paths = [ unstablePkgs.pi-coding-agent ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set-default PI_CODING_AGENT_DIR ${lib.escapeShellArg cfg.configDir} \
        --set-default PI_WEB_ACCESS_CACHE_ROOT ${lib.escapeShellArg cacheDir} \
        --suffix PATH : ${lib.makeBinPath [ unstablePkgs.nodejs ]}
    '';
  };
in
{
  home = {
    sessionVariables.PI_WEB_ACCESS_CACHE_ROOT = cacheDir;

    file = {
      "${cfg.configDir}/settings.json".enable = false;
      "${cfg.configDir}/sessions".source = config.lib.file.mkOutOfStoreSymlink "${stateDir}/sessions";
      "${cfg.configDir}/pi-subagents".source =
        config.lib.file.mkOutOfStoreSymlink "${stateDir}/pi-subagents";
    };

    activation.configurePi = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run install -d -m 700 ${
        lib.escapeShellArgs [
          cfg.configDir
          "${stateDir}/sessions"
          "${stateDir}/pi-subagents"
          cacheDir
        ]
      }
      if [[ ! -v DRY_RUN ]]; then
        settings=${lib.escapeShellArg "${cfg.configDir}/settings.json"}
        previous="$settings"
        if [[ ! -f "$previous" ]]; then
          previous=${pkgs.writeText "pi-empty-settings.json" "{}"}
        fi
        next="$(mktemp "$settings.XXXXXX")"
        if ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$previous" ${settings} > "$next"; then
          chmod 600 "$next"
          mv -f "$next" "$settings"
        else
          rm -f "$next"
          exit 1
        fi
      fi
    '';
  };

  xdg.configFile.pi = {
    source = piConfig;
    recursive = true;
  };

  programs.pi-coding-agent = {
    enable = true;
    package = pi;
    configDir = "${config.xdg.configHome}/pi";
    context = ../../config/opencode/AGENTS.md;
    settings = {
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6-astra";
      defaultThinkingLevel = "medium";
      theme = "dracula";
      hideThinkingBlock = false;
      steeringMode = "all";
      followUpMode = "all";
      enableInstallTelemetry = false;
      packages = [
        "npm:pi-subagents"
        "npm:pi-web-access"
        "npm:@gotgenes/pi-anthropic-auth"
        "npm:pi-multi-pass"
      ];
    };
  };
}
