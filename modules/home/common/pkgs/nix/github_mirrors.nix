{
  owner,
  forge,
  excluded ? [ ],
  interval ? "8h0m0s",
  onCalendar ? "hourly",
}:
{ config, pkgs, ... }:
let
  settings = pkgs.writeText "github-mirrors.json" (
    builtins.toJSON {
      inherit
        owner
        forge
        excluded
        interval
        ;
      github = {
        api = "https://api.github.com";
        web = "https://github.com";
        ssh = "ssh://git@github.com";
      };
    }
  );
  script = pkgs.writeShellApplication {
    name = "github-mirrors";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.git
      pkgs.gnused
      pkgs.jq
      config.homeSops.bootstrap
    ];
    text = builtins.readFile ../bin/github-mirrors.sh;
  };
in
{
  systemd.user.services.github-mirrors = {
    Unit = {
      Description = "Push mirror every ${owner} Forgejo repository to GitHub";
      Wants = [ "sops-nix.service" ];
      After = [ "sops-nix.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${script}/bin/github-mirrors ${settings}";
      TimeoutStartSec = 600;
    };
  };

  systemd.user.timers.github-mirrors = {
    Unit.Description = "Timer for github-mirrors";
    Timer = {
      OnCalendar = onCalendar;
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
