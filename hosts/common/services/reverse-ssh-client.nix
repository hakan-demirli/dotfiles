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

  ...
}:
let
  reverseSshUser = username; # "autossh"
  # # Usage
  # ❯ ssh -J emre@sshr.polarbearvuzi.com emre@localhost -p 42069
  #
  # # Debugging
  # ❯ sudo systemctl restart autossh-reverse-tunnel.service
  # ❯ systemctl status autossh-reverse-tunnel.service
  # ❯ chmod 700 /persist/home/Desktop/dotfiles/secrets/.ssh
  # ❯ sudo chmod  400 /persist/home/Desktop/dotfiles/secrets/.ssh/id_ed25519*
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
      monitoringPort = 0;

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
