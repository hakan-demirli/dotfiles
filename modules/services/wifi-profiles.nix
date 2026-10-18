{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.wifiProfiles;

  installProfiles = pkgs.writeShellApplication {
    name = "install-wifi-profiles";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.networkmanager
      pkgs.python3
      pkgs.remarshal
      pkgs.sops
    ];
    text = ''
      set -euo pipefail
      umask 077

      key_file=${lib.escapeShellArg cfg.keyFile}
      sops_file=${lib.escapeShellArg cfg.sopsFile}
      output_dir=${lib.escapeShellArg cfg.profilesDirectory}

      if [[ ! -s "$key_file" ]]; then
        echo "wifi-profiles: identity is missing: $key_file" >&2
        exit 1
      fi

      staging="$RUNTIME_DIRECTORY/staging"
      rm -rf "$staging"
      mkdir -p "$staging"
      trap 'rm -rf "$staging"' EXIT

      SOPS_AGE_KEY_FILE="$key_file" sops --decrypt "$sops_file" \
        | remarshal -if yaml -of json > "$staging/networks.json"

      managed=$(python3 ${./wifi-profiles.py} \
        --networks "$staging/networks.json" \
        --out-dir "$staging/profiles" 2>&1 >/dev/null \
        | grep -E '^[0-9a-f-]{36}$' || true)

      install -d -m 0700 "$output_dir"
      for f in "$staging/profiles"/*.nmconnection; do
        uuid="$(basename "$f" .nmconnection)"
        install -m 0600 "$f" "$output_dir/wifi-profiles-$uuid.nmconnection"
      done

      for existing in "$output_dir"/wifi-profiles-*.nmconnection; do
        [[ -e $existing ]] || continue
        uuid="$(basename "$existing" .nmconnection)"
        uuid="''${uuid#wifi-profiles-}"
        grep -qxF "$uuid" <<< "$managed" || rm -f "$existing"
      done

      nmcli connection reload
    '';
  };
in
{
  options.services.wifiProfiles = {
    enable = lib.mkEnableOption "sops-backed NetworkManager Wi-Fi profiles";

    sopsFile = lib.mkOption {
      type = lib.types.path;
      description = "Canonical Wi-Fi document. Networks are enumerated from it.";
    };

    keyFile = lib.mkOption {
      type = lib.types.str;
      description = "age identity able to decrypt sopsFile.";
    };

    profilesDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/run/NetworkManager/system-connections";
      description = "Where rendered profiles are installed.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.wifi-profiles = {
      description = "Install SOPS-backed NetworkManager profiles";
      wantedBy = [ "multi-user.target" ];
      requires = [ "NetworkManager.service" ];
      after = [ "NetworkManager.service" ];
      restartTriggers = [ cfg.sopsFile ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "wifi-profiles";
        RuntimeDirectoryMode = "0700";
        ExecStart = lib.getExe installProfiles;
      };
    };
  };
}
