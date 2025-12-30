{
  inputs,
  ...
}:
{
  # SLURM client-only configuration
  flake.modules.nixos.services-slurm-client = { config, lib, ... }:
  let
    cfg = config.services.slurm-client;
  in
  {
    options.services.slurm-client = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable SLURM client-only (submit jobs, no execution)";
      };
      masterHostname = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Hostname of the SLURM master node";
      };
    };

    config = lib.mkIf cfg.enable {
      services = {
        timesyncd.enable = true;
        munge.enable = true;
        slurm = {
          enableStools = true;
          controlMachine = cfg.masterHostname;
          clusterName = "nixos-slurm";
          extraConfig = ''
            AuthType=auth/none
            CryptoType=crypto/none
          '';
        };
      };

      environment.etc."munge/munge.key" = {
        text = "mungeverryweakkeybuteasytointegratoinatest";
        mode = "0400";
        user = "munge";
        group = "munge";
      };

      users.users.slurm = {
        isSystemUser = true;
        group = "slurm";
      };
      users.groups.slurm = {};
    };
  };
}
