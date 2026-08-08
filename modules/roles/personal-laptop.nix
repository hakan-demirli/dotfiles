{
  inputs,
  lib,
  pkgs,
  host,
  cluster,
  ...
}:
let
  ownerId = host.ownership.owner;
  owner = cluster.users.${ownerId};
  ownerUsername = owner.system_account.username;
  ownerUid = owner.system_account.uid;
  userManagedHome =
    (host.impermanence.enable or false)
    && (host.impermanence.home_mode or "persist-all") == "user-managed";
  collisionResolver = pkgs.writeShellApplication {
    name = "home-generation-replay-collisions";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.findutils
    ];
    text = builtins.readFile ./home-generation-replay-collisions.sh;
  };
  upstreamReplay = pkgs.writeShellApplication {
    name = "home-generation-replay-upstream";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.findutils
    ];
    text = builtins.readFile (
      inputs.infra-lib + "/modules/system/home-storage/home-generation-replay.sh"
    );
  };
  replay = pkgs.writeShellApplication {
    name = "home-generation-replay";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${collisionResolver}/bin/home-generation-replay-collisions "$@"

      status=0
      ${upstreamReplay}/bin/home-generation-replay-upstream "$@" || status=$?
      if (( status == 0 )); then
        exit 0
      fi

      home=$2
      control="$home/.storage/control"
      current_target="$(readlink "$control/current" 2>/dev/null || true)"
      case "$current_target" in
        generations/*/home-storage-policy)
          generation_id="''${current_target#generations/}"
          generation_id="''${generation_id%/home-storage-policy}"
          ;;
        *) generation_id= ;;
      esac
      if [[ -n "$generation_id" && "$generation_id" != */* ]]; then
        generation="$(readlink -e "$control/generations/$generation_id" 2>/dev/null || true)"
        restored="$(readlink -e "$home/.local/state/home-manager/gcroots/current-home" 2>/dev/null || true)"
        if [[ -n "$generation" && "$restored" == "$generation" ]]; then
          echo "home-generation-replay: optional boot replay failed after restoring $generation" >&2
          exit 0
        fi
      fi
      exit "$status"
    '';
  };
in
{
  services = {
    sops.bootstrap.passwordAccount = "owner";

    openssh.settings.PermitRootLogin = lib.mkForce "no";

    pipewire.wireplumber.extraConfig."10-bluetooth-policy"."wireplumber.settings" = {
      "bluetooth.autoswitch-to-headset-profile" = false;
    };

    tailscale.loginServerHost = "sshr.polarbearvuzi.com";

    yubikey.pamOrigin = "pam://emre-sudo";

    displayManager.sddm.theme = "sddm-astronaut-theme";

    vector.settings.sinks.victorialogs = {
      buffer = {
        type = "disk";
        max_size = 1024 * 1024 * 1024;
        when_full = "block";
      };
      request = lib.mkForce {
        timeout_secs = 10;
        retry_initial_backoff_secs = 1;
        retry_max_duration_secs = 60;
      };
      retry_strategy.type = "all";
    };
  };

  system.impermanence.persistentDirs = lib.optionals (host.impermanence.enable or false) [
    "/var/lib/private/vector"
  ];

  system.activationScripts = lib.mkIf (host.impermanence.enable or false) {
    vectorStateDirectory = {
      deps = [ "createPersistentStorageDirs" ];
      text = ''
        ${pkgs.coreutils}/bin/mkdir -p /var/lib/private /persist/system/var/lib/private
        ${pkgs.coreutils}/bin/chmod 0700 /var/lib/private /persist/system/var/lib/private
      '';
    };
  };

  systemd.services = {
    vector.serviceConfig.KillSignal = "SIGQUIT";
  }
  // lib.optionalAttrs userManagedHome {
    "home-generation-replay-${ownerUsername}".serviceConfig.ExecStart =
      lib.mkForce "${replay}/bin/home-generation-replay ${ownerUsername} /home/${ownerUsername}";

    display-manager = {
      after = [ "home-storage-user@${toString ownerUid}.service" ];
      requires = [ "home-storage-user@${toString ownerUid}.service" ];
    };
  };

  users.users.${ownerUsername} = {
    linger = true;
    extraGroups = [
      "input"
      "uinput"
    ];
  };

  environment.systemPackages = [
    (pkgs.callPackage ../pkgs/sddm-astronaut.nix { })
  ];

  fonts.packages = [
    (pkgs.callPackage ../pkgs/ms-fonts.nix { })
  ];
}
