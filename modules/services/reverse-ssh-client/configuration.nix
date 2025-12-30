{
  inputs,
  ...
}:
{
  # Reverse SSH tunnel client service
  flake.modules.nixos.services-reverse-ssh-client = { config, pkgs, lib, ... }:
  let
    cfg = config.services.reverse-ssh-client;
  in
  {
    options.services.reverse-ssh-client = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable reverse SSH tunnel client";
      };
      username = lib.mkOption {
        type = lib.types.str;
        default = "emre";
        description = "Username for autossh";
      };
      remoteHost = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Remote SSH bounce server host";
      };
      remotePort = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "Remote port to bind on the bounce server";
      };
      remoteUser = lib.mkOption {
        type = lib.types.str;
        default = "emre";
        description = "Username on the remote bounce server";
      };
      localTargetPort = lib.mkOption {
        type = lib.types.int;
        default = 22;
        description = "Local port to forward to";
      };
      localTargetHost = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Local host to forward to";
      };
      privateKeyPath = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Path to SSH private key for tunnel";
      };
      sessionName = lib.mkOption {
        type = lib.types.str;
        default = "reverse-tunnel";
        description = "Name of the autossh session";
      };
      remoteBindAddress = lib.mkOption {
        type = lib.types.str;
        default = "localhost";
        description = "Address to bind on remote (use 0.0.0.0 for all interfaces)";
      };
    };

    config = lib.mkIf cfg.enable {
      environment.systemPackages = [ pkgs.autossh ];

      users.users.${cfg.username} = {
        group = cfg.username;
      };
      users.groups.${cfg.username} = {};

      services.autossh.sessions = [
        {
          name = cfg.sessionName;
          user = cfg.username;
          monitoringPort = 0;

          extraArguments = toString ([
            "-N"  # No remote command
            "-T"  # Disable pseudo-tty
            "-i" "${cfg.privateKeyPath}"
            "-R" "${cfg.remoteBindAddress}:${toString cfg.remotePort}:${cfg.localTargetHost}:${toString cfg.localTargetPort}"
            "-o" "ServerAliveInterval=60"
            "-o" "ServerAliveCountMax=3"
            "-o" "ExitOnForwardFailure=yes"
            "-o" "UserKnownHostsFile=/dev/null"
            "-o" "StrictHostKeyChecking=no"
          ] ++ [
            "${cfg.remoteUser}@${cfg.remoteHost}"
          ]);
        }
      ];
    };
  };
}
