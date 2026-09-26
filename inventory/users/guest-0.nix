{
  id = "guest-0";
  cohort = "staff";
  admin_scopes = [ ];
  headscale_user = "guest-0";
  allowed_hosts = [ "shared-server-1" ];

  system_account = {
    username = "guest0";
    uid = 1001;
  };

  keys.ssh = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA1cTXbz6YcmRiAZ5YpCTcbko4dpiCA4r2HcLTpOvrvd guest-0"
  ];
}
