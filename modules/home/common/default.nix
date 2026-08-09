{
  config,
  pkgs,
  lib,
  facts,
  ...
}:
let
  nixTailnetCache = "100.64.0.1:5101";
  nixTailnetCacheTag = "tag:nix-binary-cache";
  nixConfigDir = "${config.xdg.configHome}/nix";
  nixTailnetCacheState = "${nixConfigDir}/tailnet-cache.conf";
  nixTailnetCacheUpdater = pkgs.writeShellApplication {
    name = "update-nix-tailnet-cache";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.jq
      pkgs.nix
      pkgs.tailscale
    ];
    text = ''
      config_dir=${lib.escapeShellArg nixConfigDir}
      state_file=${lib.escapeShellArg nixTailnetCacheState}
      tailnet_cache=${lib.escapeShellArg nixTailnetCache}
      tailnet_cache_tag=${lib.escapeShellArg nixTailnetCacheTag}
      refresh="''${1:-}"

      mkdir -p "$config_dir"
      if tailscale status --json 2>/dev/null \
        | jq -e --arg tag "$tailnet_cache_tag" \
          '.BackendState == "Running" and ((.Self.Tags // []) | index($tag) != null)' >/dev/null; then
        marker='# tailnet-cache: online'
      else
        marker='# tailnet-cache: offline'
      fi

      if [[ $refresh != --refresh && -r $state_file ]]; then
        IFS= read -r current_marker < "$state_file" || true
        if [[ $current_marker == "$marker" ]]; then
          exit 0
        fi
      fi

      staged="$(mktemp "$config_dir/.tailnet-cache.conf.XXXXXX")"
      trap 'rm -f "$staged"' EXIT
      printf '%s\n' "$marker" > "$staged"

      if [[ $marker == '# tailnet-cache: offline' ]]; then
        configured="$(env -u NIX_CONFIG NIX_USER_CONF_FILES=/dev/null nix config show substituters)"
        read -r -a configured_substituters <<< "$configured"
        offline_substituters=()

        for substituter in "''${configured_substituters[@]}"; do
          if [[ $substituter != *"$tailnet_cache"* ]]; then
            offline_substituters+=("$substituter")
          fi
        done

        printf 'substituters = %s\n' "''${offline_substituters[*]}" >> "$staged"
      fi

      chmod 0600 "$staged"
      if [[ -e "$state_file" ]] && cmp -s "$staged" "$state_file"; then
        rm -f "$staged"
      else
        mv -f "$staged" "$state_file"
      fi
      trap - EXIT
    '';
  };
in
{
  imports = [
    ./modules/portablehome.nix
    ./modules/home-storage.nix
  ];

  nixpkgs.overlays = [
    (import ./pkgs/nix/overlay.nix {
      hasNvidia = facts.hasNvidia or false;
    })
  ];

  news.display = "silent";

  programs = {
    bash = {
      enable = true;
      historyFile = "$HOME/.local/state/bash/history";
      historyFileSize = -1;
      historySize = -1;
      historyControl = [
        "ignoredups"
        "ignorespace"
        "erasedups"
      ];
      shellOptions = [
        "histappend"
        "checkwinsize"
        "extglob"
        "globstar"
        "checkjobs"
        "autocd"
      ];
      bashrcExtra = ''
        export LESS='-R --use-color -Dd+r$Du+b'
        PROMPT_COMMAND="history -a; history -n"
      '';
      initExtra = ''
        if [ -f "$HOME/.config/bash/main.sh" ]; then
          # shellcheck source=/dev/null
          source "$HOME/.config/bash/main.sh"
        fi
      '';
    };
  };

  home.activation = {
    backupExistingFiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      export HOME_MANAGER_BACKUP_EXT=hm-backup
      export HOME_MANAGER_BACKUP_OVERWRITE=1
    '';
    bashHistoryDir = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      mkdir -p "$HOME/.local/state/bash"
    '';
    factsAvailable = ''
      echo "infra-home activating for ${facts.id} (cluster=${toString facts.cluster}, roles=[${pkgs.lib.concatStringsSep "," facts.roles}])"
    '';
    nixTailnetCache = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${nixTailnetCacheUpdater}/bin/update-nix-tailnet-cache --refresh
    '';
  };

  systemd.user.services.nix-tailnet-cache = {
    Unit.Description = "Update Nix cache availability from Tailscale state";
    Service = {
      Type = "oneshot";
      ExecStart = "${nixTailnetCacheUpdater}/bin/update-nix-tailnet-cache";
    };
  };

  systemd.user.timers.nix-tailnet-cache = {
    Unit.Description = "Refresh Tailnet Nix cache availability";
    Timer = {
      OnActiveSec = "1s";
      OnUnitActiveSec = "15s";
      AccuracySec = "1s";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
