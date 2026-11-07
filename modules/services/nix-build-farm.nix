{
  config,
  lib,
  cluster,
  host,
  ...
}:
let
  cfg = config.services.nix-build-farm;

  user = "nix-builder";
  clientKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJu+mS+liA9ur+EzcRcWnVNw0VccgCKnZedudl3ScqnO nix-build-farm";
  sopsKey = "nix-build-farm/ssh-key";

  builders = cluster.hostsByDeploymentRole.server-dev;
  isBuilder = lib.elem host.id builders;
  remoteBuilders = lib.remove host.id builders;

  hostNameOf = id: "${id}.ts.${config.services.tailscale.loginServerHost}";

  threadsOf =
    hardware:
    if hardware.cpu_logical_count != null then
      hardware.cpu_logical_count
    else
      hardware.cpu_cores_per_socket * hardware.cpu_sockets * hardware.cpu_threads_per_core;

  machine =
    id:
    let
      inherit (cluster.hosts.${id}) hardware;
    in
    {
      hostName = hostNameOf id;
      sshUser = user;
      sshKey = config.sops.secrets.${sopsKey}.path;
      protocol = "ssh-ng";
      systems = [ hardware.arch ];
      maxJobs = lib.max 1 (threadsOf hardware / 8);
      speedFactor = threadsOf hardware;
      supportedFeatures = [
        "nixos-test"
        "benchmark"
        "big-parallel"
        "kvm"
      ];
    };
in
{
  options.services.nix-build-farm.offload = lib.mkOption {
    type = lib.types.bool;
    default = !isBuilder;
    description = "Whether this host sends builds for the builders' systems to the server-dev build farm.";
  };

  config = lib.mkMerge [
    (lib.mkIf isBuilder {
      users = {
        users.${user} = {
          isSystemUser = true;
          group = user;
          useDefaultShell = true;
          openssh.authorizedKeys.keys = [ clientKey ];
        };
        groups.${user} = { };
      };

      nix.settings.trusted-users = [ user ];
    })

    (lib.mkIf cfg.offload {
      sops.secrets.${sopsKey} = { };

      nix = {
        distributedBuilds = true;
        settings.builders-use-substitutes = true;
        buildMachines = map machine remoteBuilders;
      };

      programs.ssh.knownHosts = lib.genAttrs remoteBuilders (id: {
        hostNames = [ (hostNameOf id) ];
        publicKey =
          cluster.hosts.${id}.labels.ssh_host_ed25519
            or (throw "nix-build-farm: builder ${id} needs labels.ssh_host_ed25519 in its inventory entry");
      });
    })
  ];
}
