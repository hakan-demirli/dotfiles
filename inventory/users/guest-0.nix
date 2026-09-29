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
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCg0nrR2/rk6e/wDwAK9Ev0ufQotAz4b45Qok0UPGHbGIRGctgJveN1BSPLNSU2W0CLQHjL00djf/jonj4y7qsxNavox79rWmfqooGfR48jsjnkpY7tfmGA/x5hGyAdBGrrUJHH2e8JhXX4KH3bno1iZ4rNxpPHksUpPeRkqsGU88apbI2xRvjQD0/1gXU+31cHZozCpvcTQg51OfN2SJ3hjpGMoFMpMxShBPlzWsSaxMnWe+Chy3Fyog6EZ/7r01ZvNPW9vpzUGgyYbRZivUpGiaENOhopbPojWbd4yFLqttd8PxtlKF5T8yFdTL0UnFfcp38kxWdq76c9x9jQNzkJ guest-0"
  ];
}
