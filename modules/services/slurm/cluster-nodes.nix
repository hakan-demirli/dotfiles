_: {
  flake.modules.nixos.slurm-cluster-nodes =
    { ... }:
    {
      services.slurm-cluster = {
        masterHostname = "vm-oracle-aarch64";
        clusterNodes = [
          {
            hostName = "vm-oracle-aarch64";
            cores = 4;
            ramMb = 21000;
          }
          {
            hostName = "s01";
            cores = 16;
            ramMb = 77000;
          }
          {
            hostName = "s02";
            cores = 8;
            ramMb = 14500;
          }
        ];
      };
    };
}
