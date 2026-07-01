_: {
  services.tailscale.loginServerHost = "sshr.polarbearvuzi.com";

  services.slurm-client = {
    enable = true;
    masterHostname = "vps-oracle-0";
  };

  users.users.emre.linger = true;
}
