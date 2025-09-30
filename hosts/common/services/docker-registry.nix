{ ... }:
{
  services.dockerRegistry = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 5000;

    storagePath = "/var/lib/docker-registry-data";
    enableDelete = true;
    enableGarbageCollect = true;
    garbageCollectDates = "daily";
  };

  environment.persistence."/persist/system".directories = [
    "/var/lib/docker-registry-data"
  ];
}
