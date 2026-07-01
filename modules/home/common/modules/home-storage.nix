{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homeStorage;
  storageType = lib.types.enum [
    "persistent"
    "temporary"
  ];
  structuredEntry = lib.types.submodule {
    options = {
      storage = lib.mkOption { type = storageType; };
      type = lib.mkOption {
        type = lib.types.enum [
          "directory"
          "file"
        ];
        default = "directory";
      };
    };
  };

  entries = lib.mapAttrs (
    _: value:
    if builtins.isString value then
      {
        storage = value;
        type = "directory";
      }
    else
      value
  ) cfg.paths;
  paths = lib.sort builtins.lessThan (lib.attrNames entries);
  components = path: lib.splitString "/" path;
  validPath =
    path:
    path != ""
    && builtins.stringLength path <= 4096
    && !lib.hasPrefix "/" path
    && !lib.hasSuffix "/" path
    && !lib.hasInfix "\u0000" path
    && lib.all (
      component:
      component != "" && component != "." && component != ".." && builtins.stringLength component <= 255
    ) (components path)
    && path != ".storage"
    && !lib.hasPrefix ".storage/" path
    && path != ".home-storage"
    && !lib.hasPrefix ".home-storage/" path;
  invalidPaths = lib.filter (path: !validPath path) paths;
  overlaps = lib.filter (pair: pair.left != pair.right && lib.hasPrefix "${pair.left}/" pair.right) (
    lib.concatMap (left: map (right: { inherit left right; }) paths) paths
  );

  parentPaths =
    path:
    let
      parts = components path;
      count = lib.length parts;
    in
    if count <= 1 then
      [ ]
    else
      map (length: lib.concatStringsSep "/" (lib.take length parts)) (lib.range 1 (count - 1));
  home = config.home.homeDirectory;
  field = value: builtins.toJSON (lib.replaceStrings [ "%" ] [ "%%" ] value);
  argumentField =
    value:
    lib.replaceStrings
      [
        "\\"
        " "
        "\t"
        "\n"
        "\r"
        "%"
      ]
      [
        "\\x5c"
        "\\x20"
        "\\t"
        "\\n"
        "\\r"
        "%%"
      ]
      value;
  directoryRule = path: "d ${field path} 0700 - - - -";
  entryRules = lib.concatMap (
    path:
    let
      entry = entries.${path};
      target = "${home}/.storage/${entry.storage}/${path}";
      homeParents = map (parent: directoryRule "${home}/${parent}") (parentPaths path);
      targetParents = map (parent: directoryRule "${home}/.storage/${entry.storage}/${parent}") (
        parentPaths path
      );
      targetRule =
        if entry.type == "directory" then directoryRule target else "f ${field target} 0600 - - - -";
    in
    homeParents
    ++ targetParents
    ++ [
      targetRule
      "L ${field "${home}/${path}"} - - - - ${argumentField target}"
    ]
  ) paths;
  layoutContents =
    lib.concatStringsSep "\n" (lib.unique entryRules) + lib.optionalString (entryRules != [ ]) "\n";
  layout = pkgs.writeText "home-storage-layout.conf" layoutContents;
  policyGeneration = pkgs.runCommand "home-storage-policy-generation" { } ''
    mkdir -p "$out"
    cp ${layout} "$out/layout.conf"
    ${lib.optionalString (cfg.default == "temporary") ''
      touch "$out/temporary-default"
    ''}
  '';

  mkDconfKeyValue = key: value: "${key}=${toString (lib.hm.gvariant.mkValue value)}";
  toDconfIni = lib.generators.toINI { mkKeyValue = mkDconfKeyValue; };
  dconfDatabases =
    lib.optional (config.dconf.settings != { }) {
      profile = null;
      settings = config.dconf.settings;
    }
    ++ lib.mapAttrsToList (name: settings: {
      profile = pkgs.writeText "dconf-profile-${name}" ''
        user-db:${name}
      '';
      inherit settings;
    }) config.dconf.databases;
  bootReplay = pkgs.writeShellScript "home-manager-boot-replay" (
    ''
      set -euo pipefail
    ''
    + lib.concatMapStrings (
      database:
      let
        ini = pkgs.writeText "home-manager-boot-dconf.ini" (toDconfIni database.settings);
        profileEnvironment = lib.optionalString (
          database.profile != null
        ) "${pkgs.coreutils}/bin/env DCONF_PROFILE=${database.profile} ";
      in
      ''
        ${pkgs.dbus}/bin/dbus-run-session \
          --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon \
          ${profileEnvironment}${pkgs.dconf}/bin/dconf load / < ${ini}
      ''
    ) dconfDatabases
  );

  autoMigrate = lib.concatMapStringsSep "\n" (
    path:
    let
      entry = entries.${path};
      managed = "${home}/${path}";
      target = "${home}/.storage/${entry.storage}/${path}";
      legacyTarget = "${home}/.home-storage/${entry.storage}/${path}";
      targetDir = builtins.dirOf target;
      ensureTarget =
        if entry.type == "directory" then
          ''
            ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg target}
            if [[ ! -d ${lib.escapeShellArg target} ]]; then
              echo "home-storage: expected a directory at ${lib.escapeShellArg target}" >&2
              exit 1
            fi
          ''
        else
          ''
            ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg targetDir}
            if [[ ! -e ${lib.escapeShellArg target} && ! -L ${lib.escapeShellArg target} ]]; then
              ${pkgs.coreutils}/bin/install -m 0600 /dev/null ${lib.escapeShellArg target}
            elif [[ ! -f ${lib.escapeShellArg target} ]]; then
              echo "home-storage: expected a file at ${lib.escapeShellArg target}" >&2
              exit 1
            fi
          '';
    in
    ''
      if [[ -L ${lib.escapeShellArg managed} ]] && [[ "$(${pkgs.coreutils}/bin/readlink ${lib.escapeShellArg managed})" == ${lib.escapeShellArg target} ]]; then
        ${ensureTarget}
      elif [[ -L ${lib.escapeShellArg managed} ]] && [[ "$(${pkgs.coreutils}/bin/readlink ${lib.escapeShellArg managed})" == ${lib.escapeShellArg legacyTarget} ]]; then
        echo "home-storage: relinking legacy path ${lib.escapeShellArg managed} -> ${lib.escapeShellArg target}" >&2
        ${ensureTarget}
        migrated=${lib.escapeShellArg "${managed}.storage-migration-"}$$
        ${pkgs.coreutils}/bin/ln -s ${lib.escapeShellArg target} "$migrated"
        ${pkgs.coreutils}/bin/mv -Tf "$migrated" ${lib.escapeShellArg managed}
      elif [[ -e ${lib.escapeShellArg managed} || -L ${lib.escapeShellArg managed} ]]; then
        echo "home-storage: migrating unmanaged path ${lib.escapeShellArg managed} -> ${lib.escapeShellArg target}" >&2
        ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg targetDir}
        if [[ -e ${lib.escapeShellArg target} ]]; then
          ${pkgs.coreutils}/bin/rmdir ${lib.escapeShellArg target} >/dev/null 2>&1 \
            || { echo "home-storage: cannot migrate because target ${lib.escapeShellArg target} is not empty" >&2; exit 1; }
        fi
        ${pkgs.coreutils}/bin/mv ${lib.escapeShellArg managed} ${lib.escapeShellArg target}
        ${pkgs.coreutils}/bin/ln -s ${lib.escapeShellArg target} ${lib.escapeShellArg managed}
      else
        ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg targetDir}
        ${ensureTarget}
        ${pkgs.coreutils}/bin/ln -s ${lib.escapeShellArg target} ${lib.escapeShellArg managed}
      fi
    ''
  ) paths;
in
{
  options.homeStorage = {
    enable = lib.mkEnableOption "user-managed persistent and temporary home storage";

    default = lib.mkOption {
      type = storageType;
      default = "persistent";
      description = "Storage class for the home root at the next boot.";
    };

    paths = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either storageType structuredEntry);
      default = { };
      example = {
        Desktop = "persistent";
        ".cache" = "temporary";
        ".config/example.conf" = {
          storage = "persistent";
          type = "file";
        };
      };
      description = "Relative home paths routed to an explicit storage bucket.";
    };

    publishAfter = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "reloadSystemd" ];
      description = "Activation entries that must succeed before publishing the boot generation.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = invalidPaths == [ ];
        message = "homeStorage paths must be normalized, relative, nonempty UTF-8 paths with components no longer than 255 bytes. .storage and legacy .home-storage are reserved. Invalid: ${lib.concatStringsSep ", " invalidPaths}";
      }
      {
        assertion = overlaps == [ ];
        message = "homeStorage paths must not overlap as ancestors and descendants.";
      }
    ];

    home = {
      activationGenerateGcRoot = false;
      extraBuilderCommands = ''
        ln -s ${policyGeneration} "$out/home-storage-policy"
        ln -s ${bootReplay} "$out/boot-replay"
      '';
      activation = {
        protectHomeStorageGeneration = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
          run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$newGenGcPath")"
          trap '${pkgs.coreutils}/bin/rm -f "$newGenGcPath" || true' EXIT
          run --silence ${pkgs.nix}/bin/nix-store --realise "$newGenPath" --add-root "$newGenGcPath"
        '';

        homeStoragePolicy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if ! ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg "${home}/.storage/persistent"} \
            || ! ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg "${home}/.storage/temporary"} \
            || ! ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg "${home}/.storage/control"}; then
            verboseEcho "home-storage facility unavailable. Leaving standalone Home Manager behavior unchanged"
          else
            ${autoMigrate}
          fi
        '';

        publishHomeStorageGeneration =
          lib.hm.dag.entryAfter ([ "homeStoragePolicy" ] ++ cfg.publishAfter)
            ''
              control=${lib.escapeShellArg "${home}/.storage/control"}
              persistentControl=${lib.escapeShellArg "/persist/home/${config.home.username}/control"}

              if ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg "${home}/.storage/persistent"} \
                && ${pkgs.util-linux}/bin/mountpoint -q ${lib.escapeShellArg "${home}/.storage/temporary"} \
                && ${pkgs.util-linux}/bin/mountpoint -q "$control"; then
                profileGeneration="$(${pkgs.coreutils}/bin/readlink -e "$genProfilePath" 2>/dev/null || true)"
                if [[ "$profileGeneration" != "$newGenPath" ]]; then
                  verboseEcho "home-storage: not publishing a Home Manager test generation"
                elif [[ ! "$control" -ef "$persistentControl" ]]; then
                  echo "home-storage: control mount does not match $persistentControl" >&2
                  exit 1
                else
                  generationId="''${newGenPath##*/}"
                  generations="$persistentControl/generations"
                  persistentGeneration="$generations/$generationId"

                  run ${pkgs.coreutils}/bin/mkdir -p -m 0700 "$generations"
                  if [[ -e "$persistentGeneration" || -L "$persistentGeneration" ]]; then
                    if [[ ! -L "$persistentGeneration" ]] \
                      || [[ "$(${pkgs.coreutils}/bin/readlink -e "$persistentGeneration")" != "$newGenPath" ]]; then
                      echo "home-storage: refusing generation ID collision at $persistentGeneration" >&2
                      exit 1
                    fi
                  else
                    run --silence ${pkgs.nix}/bin/nix-store --realise "$newGenPath" --add-root "$persistentGeneration"
                  fi

                  if [[ ! -r "$persistentGeneration/home-storage-policy/layout.conf" ]] \
                    || [[ ! -x "$persistentGeneration/boot-replay" ]] \
                    || [[ ! -d "$persistentGeneration/home-files" ]] \
                    || [[ ! -d "$persistentGeneration/home-path" ]]; then
                    echo "home-storage: generation $newGenPath is incomplete" >&2
                    exit 1
                  fi

                  selectedGeneration=
                  if [[ -L "$control/current" ]]; then
                    selectedTarget="$(${pkgs.coreutils}/bin/readlink "$control/current")"
                    case "$selectedTarget" in
                      generations/*/home-storage-policy)
                        selectedId="''${selectedTarget#generations/}"
                        selectedId="''${selectedId%/home-storage-policy}"
                        if [[ -n "$selectedId" && "$selectedId" != */* ]]; then
                          selectedGeneration="$generations/$selectedId"
                        fi
                        ;;
                    esac
                  fi

                  for oldGeneration in "$generations"/*-home-manager-generation; do
                    [[ -L "$oldGeneration" ]] || continue
                    if [[ "$oldGeneration" != "$persistentGeneration" \
                      && "$oldGeneration" != "$selectedGeneration" ]]; then
                      run ${pkgs.coreutils}/bin/rm "$oldGeneration"
                    fi
                  done

                  run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$currentGenGcPath")"
                  standardNext="$currentGenGcPath.next-$$"
                  run ${pkgs.coreutils}/bin/ln -s "$persistentGeneration" "$standardNext"
                  run ${pkgs.coreutils}/bin/mv -Tf "$standardNext" "$currentGenGcPath"

                  if [[ -e "$legacyGenGcPath" ]]; then
                    run ${pkgs.coreutils}/bin/rm "$legacyGenGcPath"
                  fi

                  next="$control/.current-$(${pkgs.coreutils}/bin/id -u)-$$"
                  run ${pkgs.coreutils}/bin/ln -s \
                    "generations/$generationId/home-storage-policy" "$next"
                  run ${pkgs.coreutils}/bin/mv -Tf "$next" "$control/current"
                fi
              else
                run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$currentGenGcPath")"
                if [[ -e "$legacyGenGcPath" ]]; then
                  run ${pkgs.coreutils}/bin/rm "$legacyGenGcPath"
                fi
                run --silence ${pkgs.nix}/bin/nix-store \
                  --realise "$newGenPath" --add-root "$currentGenGcPath"
              fi
            '';
      };
    };
  };
}
