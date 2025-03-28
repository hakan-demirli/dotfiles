{ pkgs, ... }:

let
  scriptUser = "emre";
  scriptHome = "/home/${scriptUser}";
  gitRepoPath = "${scriptHome}/Desktop/serveo";

  reverseSshScript = ../../.local/bin/create_reverse_ssh;
  warpConnectScript = ../../.local/bin/connect_warp;

in
{
  systemd.services = {

    warp-connect = {
      description = "Cloudflare Warp Connect Attempt Service";
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        ExecStart = "${pkgs.bash}/bin/bash ${warpConnectScript}";
        StandardOutput = "journal";
        StandardError = "journal";
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    reverse-ssh-tunnel = {
      description = "Reverse SSH Tunnel via Serveo Service";
      wantedBy = [ "multi-user.target" ]; # Start during normal boot

      after = [ "warp-connect.service" ];
      # requires = [ "warp-connect.service" ];

      serviceConfig = {
        Type = "simple";
        User = scriptUser;
        Group = "users";
        Environment = [
          "HOME=${scriptHome}"
          "USER=${scriptUser}"
          "PATH=${pkgs.coreutils}/bin:${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin"
          "GIT_CONFIG_GLOBAL=/home/emre/.config/git/config"
        ];
        WorkingDirectory = gitRepoPath;
        ExecStart = "${pkgs.bash}/bin/bash ${reverseSshScript}";
        Restart = "on-failure";
        RestartSec = "15s";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };

  systemd.timers = {
    warp-connect = {
      description = "Timer to periodically run Warp Connect check/attempt";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "warp-connect.service";
        OnBootSec = "1min";
        OnUnitActiveSec = "2min";
        RandomizedDelaySec = "3s";
      };
    };
  };
}
