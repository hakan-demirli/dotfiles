{
  pkgs,

  username ? throw "You must specify a username",

  reverseSshRemoteHost ? throw "reverseSshRemoteHost must be set for the client",
  reverseSshRemotePort ? throw "reverseSshRemotePort must be set for the client",
  reverseSshRemoteUser ? "emre",

  reverseSshLocalTargetPort ? 22,
  reverseSshLocalTargetHost ? "localhost",
  reverseSshPrivateKeyPath ? throw "reverseSshPrivateKeyPath must be set for the client",

  reverseSshSessionName ? "reverse-tunnel",
  reverseSshRemoteBindAddress ? "localhost", # 0.0.0.0
  reverseSshMonitoringPort ? 0,

  ...
}:
let
  reverseSshUser = username; # "autossh"
in
{
  environment.systemPackages = [ pkgs.autossh ];

  users.users.${reverseSshUser} = {
    group = reverseSshUser;

    # uncomment if username is not the same as reverseSshUser
    # home = "/var/lib/${reverseSshUser}";
    # createHome = true;
    # isSystemUser = true;
  };
  users.groups.${reverseSshUser} = { };

  services.autossh.sessions = [
    {
      name = reverseSshSessionName;
      user = reverseSshUser;
      monitoringPort = reverseSshMonitoringPort;

      extraArguments = toString (
        [
          "-N" # No remote command
          "-T" # Disable pseudo-tty
          "-i"
          "${reverseSshPrivateKeyPath}"
          "-R"
          "${reverseSshRemoteBindAddress}:${toString reverseSshRemotePort}:${reverseSshLocalTargetHost}:${toString reverseSshLocalTargetPort}"
          "-o"
          "ServerAliveInterval=60"
          "-o"
          "ServerAliveCountMax=3"
          "-o"
          "ExitOnForwardFailure=yes"
          "-o"
          "StrictHostKeyChecking=accept-new"
        ]
        ++ [
          "${reverseSshRemoteUser}@${reverseSshRemoteHost}"
        ]
      );
    }
  ];
}
