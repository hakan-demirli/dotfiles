# pkgs/github-runner.nix
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.services.github-runners-urlFile = lib.mkOption {
    description = ''
      Configuration for multiple GitHub Actions runners.
    '';
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether to enable this GitHub Actions runner.";
            };

            url = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                Repository or organization URL to add the runner to.
                Mutually exclusive with `urlFile`.
              '';
              example = "https://github.com/nixos/nixpkgs";
            };

            urlFile = lib.mkOption {
              type = with lib.types; nullOr path;
              default = null;
              description = ''
                Path to a file containing the repository or organization URL for the runner.
                The file should not contain a trailing newline.
                Mutually exclusive with `url`.
              '';
              example = "/run/secrets/github-runner-url";
            };

            tokenFile = lib.mkOption {
              type = lib.types.path;
              description = "The full path to a file which contains the runner registration token or a Personal Access Token (PAT).";
              example = "/run/secrets/github-runner/nixos.token";
            };

            name = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              description = "Name of the runner to configure. If null, defaults to the service instance name.";
              default = name;
            };

            runnerGroup = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              description = "Name of the runner group to add this runner to.";
              default = null;
            };

            extraLabels = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Extra labels in addition to the default ones.";
              default = [ ];
            };

            noDefaultLabels = lib.mkOption {
              type = lib.types.bool;
              description = "Disables adding the default labels.";
              default = false;
            };

            replace = lib.mkOption {
              type = lib.types.bool;
              description = "Replace any existing runner with the same name.";
              default = false;
            };

            ephemeral = lib.mkOption {
              type = lib.types.bool;
              description = "Configure the runner to be ephemeral (one job per run).";
              default = false;
            };

            package = lib.mkPackageOption pkgs "github-runner" { };

            user = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              description = "User under which to run the service.";
              default = null;
            };

            group = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              description = "Group under which to run the service.";
              default = null;
            };

            extraPackages = lib.mkOption {
              type = lib.types.listOf lib.types.package;
              description = "Extra packages to add to `PATH` of the service.";
              default = [ ];
            };

            extraEnvironment = lib.mkOption {
              type = lib.types.attrs;
              description = "Extra environment variables to set for the runner.";
              default = { };
            };

            serviceOverrides = lib.mkOption {
              type = lib.types.attrs;
              description = "Modify the systemd service.";
              default = { };
            };

            workDir = lib.mkOption {
              type = with lib.types; nullOr str;
              description = "Working directory for the runner.";
              default = null;
            };

            nodeRuntimes = lib.mkOption {
              type = with lib.types; nonEmptyListOf (lib.types.enum [ "node20" ]);
              default = [ "node20" ];
              description = "List of Node.js runtimes the runner should support.";
            };
          };
        }
      )
    );
  };

  config = {
    assertions = lib.flatten (
      lib.flip lib.mapAttrsToList config.services.github-runners-urlFile (
        name: cfg:
        map (lib.mkIf cfg.enable) [
          {
            assertion = (cfg.url != null) != (cfg.urlFile != null);
            message = "`services.github-runners.${name}`: You must specify exactly one of `url` or `urlFile`.";
          }
          {
            assertion = !cfg.noDefaultLabels || (cfg.extraLabels != [ ]);
            message = "`services.github-runners.${name}`: The `extraLabels` option is mandatory if `noDefaultLabels` is set";
          }
          {
            assertion = cfg.group == null || cfg.user != null;
            message = ''`services.github-runners.${name}`: Setting `group` while leaving `user` unset runs the service as `root`. If this is really what you want, set `user = "root"` explicitly'';
          }
        ]
      )
    );

    systemd.services =
      let
        enabledRunners = lib.filterAttrs (_: cfg: cfg.enable) config.services.github-runners-urlFile;
      in
      (lib.flip lib.mapAttrs' enabledRunners (
        name: cfg:
        let
          svcName = "github-runner-${name}";
          systemdDir = "github-runner/${name}";
          runtimeDir = "%t/${systemdDir}";
          stateDir = "%S/${systemdDir}";
          logsDir = "%L/${systemdDir}";
          currentConfigTokenFilename = ".current-token";
          currentConfigUrlFilename = ".current-url";
          workDir = if cfg.workDir == null then runtimeDir else cfg.workDir;
          package = cfg.package.override (
            old: lib.optionalAttrs (lib.hasAttr "nodeRuntimes" old) { inherit (cfg) nodeRuntimes; }
          );
        in
        lib.nameValuePair svcName {
          description = "GitHub Actions runner";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [
            "network.target"
            "network-online.target"
          ];
          environment = {
            HOME = workDir;
            RUNNER_ROOT = stateDir;
          } // cfg.extraEnvironment;
          path = [
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.git
            pkgs.gnutar
            pkgs.gzip
            config.nix.package
          ] ++ cfg.extraPackages;

          serviceConfig = lib.mkMerge [
            {
              ExecStart = "${package}/bin/Runner.Listener run --startuptype service";
              ExecStartPre =
                let
                  writeScript =
                    name: lines:
                    pkgs.writeShellScript "${svcName}-${name}.sh" ''
                      set -euo pipefail
                      STATE_DIRECTORY="$1"
                      WORK_DIRECTORY="$2"
                      LOGS_DIRECTORY="$3"
                      ${lines}
                    '';
                  runnerRegistrationConfig = lib.getAttrs [
                    "url"
                    "urlFile"
                    "tokenFile"
                    "name"
                    "runnerGroup"
                    "extraLabels"
                    "noDefaultLabels"
                    "replace"
                    "ephemeral"
                    "workDir"
                  ] cfg;
                  installOpts =
                    lib.optionalString (cfg.user != null)
                      "--owner=${cfg.user} ${lib.optionalString (cfg.group != null) "--group=${cfg.group}"}";
                  newConfigPath = builtins.toFile "${svcName}-config.json" (builtins.toJSON runnerRegistrationConfig);
                  currentConfigPath = "$STATE_DIRECTORY/.nixos-current-config.json";
                  newConfigTokenPath = "$STATE_DIRECTORY/.new-token";
                  currentConfigTokenPath = "$STATE_DIRECTORY/${currentConfigTokenFilename}";
                  currentConfigUrlPath = "$STATE_DIRECTORY/${currentConfigUrlFilename}";
                  runnerCredFiles = [
                    ".credentials"
                    ".credentials_rsaparams"
                    ".runner"
                  ];

                  unconfigureRunner = writeScript "unconfigure" ''
                    copy_secrets() {
                      install ${installOpts} --mode=0600 ${lib.escapeShellArg cfg.tokenFile} "${currentConfigTokenPath}"
                      ${lib.optionalString (cfg.urlFile != null) ''
                        install ${installOpts} --mode=0600 ${lib.escapeShellArg cfg.urlFile} "${currentConfigUrlPath}"
                      ''}
                    }
                    clean_state() {
                      find "$STATE_DIRECTORY/" -mindepth 1 -delete
                      install ${installOpts} --mode=0600 ${lib.escapeShellArg cfg.tokenFile} "${newConfigTokenPath}"
                      copy_secrets
                    }
                    diff_config() {
                      changed=0
                      # Check for module config changes
                      [[ -f "${currentConfigPath}" ]] && diff -q '${newConfigPath}' "${currentConfigPath}" >/dev/null 2>&1 || changed=1
                      # Check content of token file
                      [[ -f "${currentConfigTokenPath}" ]] && diff -q "${currentConfigTokenPath}" ${lib.escapeShellArg cfg.tokenFile} >/dev/null 2>&1 || changed=1
                      # Check content of url file
                      ${lib.optionalString (cfg.urlFile != null) ''
                        [[ -f "${currentConfigUrlPath}" ]] && diff -q "${currentConfigUrlPath}" ${lib.escapeShellArg cfg.urlFile} >/dev/null 2>&1 || changed=1
                      ''}
                      if [[ "$changed" -eq 1 ]]; then
                        echo "Config or secret file content has changed, re-registering runner."
                        clean_state
                      fi
                    }
                    if [[ "${lib.optionalString cfg.ephemeral "1"}" ]]; then
                      clean_state
                    elif [[ "$(ls -A "$STATE_DIRECTORY")" ]]; then
                      diff_config
                    else
                      install ${installOpts} --mode=0600 ${lib.escapeShellArg cfg.tokenFile} "${newConfigTokenPath}"
                      copy_secrets
                    fi
                    find -H "$WORK_DIRECTORY" -mindepth 1 -delete
                  '';

                  configureRunner = writeScript "configure" ''
                    if [[ -e "${newConfigTokenPath}" ]]; then
                      echo "Configuring GitHub Actions Runner"
                      if [[ -n "${cfg.urlFile}" ]]; then
                          runner_url="$(< "${currentConfigUrlPath}")"
                      else
                          runner_url=${lib.escapeShellArg cfg.url}
                      fi
                      # shellcheck disable=SC2054
                      args=(
                        --unattended --disableupdate --work "$WORK_DIRECTORY" --url "$runner_url"
                        --labels ${lib.escapeShellArg (lib.concatStringsSep "," cfg.extraLabels)}
                        ${lib.optionalString (cfg.name != null) "--name ${lib.escapeShellArg cfg.name}"}
                        ${lib.optionalString cfg.replace "--replace"}
                        ${lib.optionalString (
                          cfg.runnerGroup != null
                        ) "--runnergroup ${lib.escapeShellArg cfg.runnerGroup}"}
                        ${lib.optionalString cfg.ephemeral "--ephemeral"}
                        ${lib.optionalString cfg.noDefaultLabels "--no-default-labels"}
                      )
                      token=$(<"${newConfigTokenPath}")
                      if [[ "$token" =~ ^ghp_* ]] || [[ "$token" =~ ^github_pat_* ]]; then
                        args+=(--pat "$token")
                      else
                        args+=(--token "$token")
                      fi
                      ${package}/bin/Runner.Listener configure "''${args[@]}"
                      mkdir -p "$STATE_DIRECTORY/_diag" && cp -r "$STATE_DIRECTORY/_diag/." "$LOGS_DIRECTORY/" && rm -rf "$STATE_DIRECTORY/_diag/"
                      rm "${newConfigTokenPath}"
                      ln -sf '${newConfigPath}' "${currentConfigPath}"
                    fi
                  '';

                  setupWorkDir = writeScript "setup-work-dirs" ''
                    ln -s "$LOGS_DIRECTORY" "$WORK_DIRECTORY/_diag"
                    ln -s "$STATE_DIRECTORY"/{${lib.concatStringsSep "," runnerCredFiles}} "$WORK_DIRECTORY/"
                  '';
                in
                map
                  (
                    x:
                    "${x} ${
                      lib.escapeShellArgs [
                        stateDir
                        workDir
                        logsDir
                      ]
                    }"
                  )
                  [
                    "+${unconfigureRunner}"
                    configureRunner
                    setupWorkDir
                  ];

              Restart = if cfg.ephemeral then "on-success" else "no";
              RestartForceExitStatus = [ 2 ];
              LogsDirectory = [ systemdDir ];
              RuntimeDirectory = [ systemdDir ];
              StateDirectory = [ systemdDir ];
              StateDirectoryMode = "0700";
              WorkingDirectory = workDir;
              InaccessiblePaths =
                [
                  "-${cfg.tokenFile}"
                  "${stateDir}/${currentConfigTokenFilename}"
                ]
                ++ lib.optionals (cfg.urlFile != null) [
                  "-${cfg.urlFile}"
                  # "${stateDir}/${currentConfigUrlFilename}" # This was the problem
                ];
              KillSignal = "SIGINT";
              NoNewPrivileges = lib.mkDefault true;
              PrivateDevices = lib.mkDefault true;
              PrivateMounts = lib.mkDefault true;
              PrivateTmp = lib.mkDefault true;
              PrivateUsers = lib.mkDefault true;
              ProtectClock = lib.mkDefault true;
              ProtectControlGroups = lib.mkDefault true;
              ProtectHome = lib.mkDefault true;
              ProtectSystem = lib.mkDefault "strict";
              ProtectProc = lib.mkDefault "invisible";
              PrivateNetwork = lib.mkDefault false;
              DynamicUser = lib.mkDefault true;
            }
            (lib.mkIf (cfg.user != null) {
              DynamicUser = false;
              User = cfg.user;
            })
            (lib.mkIf (cfg.group != null) {
              DynamicUser = false;
              Group = cfg.group;
            })
            cfg.serviceOverrides
          ];
        }
      ));
  };
}
