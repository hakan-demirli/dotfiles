_: {
  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";

  # Problematic. Permission issues.
  # virtualisation.docker.rootless = {
  #   enable = true;
  #   setSocketVariable = true;
  # };
  environment.persistence."/persist/system" = {
    directories = [
      "/var/lib/docker"
    ];
  };
}
