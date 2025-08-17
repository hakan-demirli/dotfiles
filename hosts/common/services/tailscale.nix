{
  reverseSshRemoteHost ? throw "You must specify a reverseSshRemoteHost",
  ...
}:
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/persist/home/emre/Desktop/dotfiles/secrets/tailscale-key";
    extraUpFlags = [
      "--login-server=https://${reverseSshRemoteHost}"
    ];
  };
}
