{
  gitRepoPath ? "$HOME/.local/share/serveo",
}:
{ pkgs, ... }:
{
  systemd.user.services.reverse-ssh-tunnel = {
    Unit = {
      Description = "Reverse SSH tunnel via serveo.net";
      Wants = [ "network-online.target" ];
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.coreutils
            pkgs.git
            pkgs.openssh
            pkgs.gnugrep
            pkgs.gnused
          ]
        }"
      ];
      WorkingDirectory = gitRepoPath;
      ExecStart = "${pkgs.bash}/bin/bash ${../bin/create_reverse_ssh}";
      Restart = "on-failure";
      RestartSec = "15s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
