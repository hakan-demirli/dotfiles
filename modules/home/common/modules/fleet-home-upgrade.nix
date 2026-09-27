{
  config,
  lib,
  pkgs,
  facts,
  inputs,
  ...
}:
let
  cfg = config.fleetHomeUpgrade;
  plan = inputs.self.lib.intent.deployPlan;
  managed = plan.controller != null && plan.hosts ? ${facts.id};

  upgrade = pkgs.writeShellApplication {
    name = "fleet-home-upgrade";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.nix
    ];
    text = ''
      configuration=${lib.escapeShellArg cfg.configuration}
      plan_url=${lib.escapeShellArg cfg.planUrl}
      flake=${lib.escapeShellArg cfg.flake}
      profile="''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"

      finish() {
        echo "fleet-home-upgrade: $1 ($2)"
        exit 0
      }

      current="$(cat "$profile/fleet-revision" 2>/dev/null || true)"
      system="$(/run/current-system/sw/bin/nixos-version --configuration-revision 2>/dev/null || true)"
      plan="$(curl -fsS --connect-timeout 10 --max-time 60 "$plan_url")" || finish offline plan-unreachable
      deployed() {
        [[ $1 =~ ^[0-9a-f]{40}$ ]] && jq -e --arg revision "$1" '.history | index([$revision]) != null' <<< "$plan" > /dev/null
      }

      if ! deployed "$current"; then
        finish held local
      fi
      if ! deployed "$system"; then
        finish held system-local
      fi
      if [[ $current == "$system" ]]; then
        finish current none
      fi

      activation="$(nix build --no-link --print-out-paths \
        "$flake?rev=$system#homeConfigurations.\"$configuration\".activationPackage")"
      "$activation/activate"
      finish current none
    '';
  };
in
{
  options.fleetHomeUpgrade = {
    planUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if managed then "http://${plan.controller}.ts.sshr.polarbearvuzi.com:5102/plan.json" else null;
      description = "Deployment plan of the fleet. Null disables the upgrade timer.";
    };
    flake = lib.mkOption {
      type = lib.types.strMatching "[^?]+";
      default = "github:hakan-demirli/dotfiles";
    };
    configuration = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.username}@${facts.id}";
    };
    revision = lib.mkOption {
      type = lib.types.str;
      default = inputs.self.rev or inputs.self.dirtyRev or "unknown";
      description = "Source revision recorded in every generation.";
    };
  };

  config = lib.mkMerge [
    {
      home.extraBuilderCommands = ''
        printf '%s\n' ${lib.escapeShellArg cfg.revision} > "$out/fleet-revision"
      '';
    }

    (lib.mkIf (cfg.planUrl != null) {
      systemd.user.services.fleet-home-upgrade = {
        Unit = {
          Description = "Activate the Home Manager generation of the running system revision";
          ConditionACPower = true;
          StartLimitIntervalSec = 0;
        };
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe upgrade;
        };
      };

      systemd.user.timers.fleet-home-upgrade = {
        Unit.Description = "Follow the system revision with Home Manager";
        Timer = {
          OnCalendar = "*-*-* 04..06:05/10:00";
          Persistent = true;
          RandomizedDelaySec = "5m";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    })
  ];
}
