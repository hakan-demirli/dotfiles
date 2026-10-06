{
  id = "guest-1";
  cohort = "staff";
  admin_scopes = [ ];
  headscale_user = "guest-1";
  allowed_hosts = [ "shared-server-1" ];

  system_account = {
    username = "guest1";
    uid = 1002;
  };

  keys.ssh = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG5qliPqG2q5XhnrJ/2dGZoGGnO/QQHhoAmxxYPQfcRQ"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHAat3ky0yN+qAFeZp55g2RKWH+ijPls5U52kl0TcCP9"
  ];
}
