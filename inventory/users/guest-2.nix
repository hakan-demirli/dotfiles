{
  id = "guest-2";
  cohort = "staff";
  admin_scopes = [ ];
  headscale_user = "guest-2";
  allowed_hosts = [ "shared-server-1" ];

  system_account = {
    username = "guest2";
    uid = 1003;
  };

  keys.ssh = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPN8lmYZ966YPk+FZ9BjQjW2UUopt1dptJYoxeS+x4ap brayden-v80"
  ];
}
