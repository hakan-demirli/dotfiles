{
  id = "user-0";
  cohort = "admin";
  headscale_user = "user-0";
  allowed_hosts = [ "all" ];

  system_account = {
    username = "emre";
    uid = 1000;
  };

  keys = {
    ssh = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICDDPkxYuzRBqtndEoRNx/ua5P0KCG9gMsCe77qf+2ie emre@proton"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGWfQ0r1CkNeTdLYzsd+LPFCEwlJQN9z++BzF2Oethpn emre@main"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSqE07L1RdjIsvs/qRTRT8CjYRX8tjjaQgOdLI0J67O emre@sf"
    ];
    age = [ "age1qrjcpn8aflx485u5425atflznxqgaz0vmcp2zluhdrd7fjyj59ssuszh7y" ];
    u2f = [
      "emre:xRjZbv8vsES9CP55zOU6S4LWy/67I8bJTooq9iglolu0l9Ij5AVtwwnmgij90BHBQMnV0KrAVC5SaQfJ6VoYag==,784H6g8EzR2qUwmBdQ3mH/4d3a04aDYV8Vrk0oZWNZaajHQXbkuPtSJnKzcsrUM1jAueHBdnOz4StUYpTu9RWA==,es256,+presence"
    ];
  };
}
