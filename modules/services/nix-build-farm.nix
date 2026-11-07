{
  config,
  lib,
  pkgs,
  cluster,
  host,
  ...
}:
let
  cfg = config.services.nix-build-farm;

  user = "nix-builder";
  clientKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJu+mS+liA9ur+EzcRcWnVNw0VccgCKnZedudl3ScqnO nix-build-farm";
  sopsKey = "nix-build-farm/ssh-key";
  inherit (cluster.services.nix-build-farm) port;

  builders = cluster.hostsByDeploymentRole.server-dev;
  isBuilder = lib.elem host.id builders;
  remoteBuilders = lib.remove host.id builders;

  hostNameOf = id: "${id}.ts.${config.services.tailscale.loginServerHost}";
  aliasOf = id: "nix-build-farm-${id}";

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
      hostName = aliasOf id;
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

      # The builder port is a tailnet-only cluster service, so it must stay out of
      # services.openssh.ports, which openFirewall opens on every interface.
      services.openssh = {
        listenAddresses = lib.concatMap (
          listenPort:
          map
            (addr: {
              inherit addr;
              port = listenPort;
            })
            [
              "0.0.0.0"
              "[::]"
            ]
        ) (config.services.openssh.ports ++ [ port ]);
        extraConfig = ''
          Match LocalPort ${toString port}
            AllowUsers ${user}
          Match User ${user}
            AllowAgentForwarding no
            AllowTcpForwarding no
            PermitTTY no
            X11Forwarding no
        '';
      };

      # The builder serves the nix daemon, not slurm jobs; exempt it from session adoption.
      security.pam.services.sshd.rules.account.${user} =
        lib.mkIf (config.services.slurm-cluster.adoptSshSessions or false)
          {
            enable = true;
            control = "sufficient";
            modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
            args = [
              "quiet"
              "user"
              "="
              user
            ];
            order = config.security.pam.services.sshd.rules.account.wheel-bypass.order - 1;
          };
    })

    (lib.mkIf cfg.offload {
      sops.secrets.${sopsKey} = { };

      nix = {
        distributedBuilds = true;
        settings.builders-use-substitutes = true;
        buildMachines = map machine remoteBuilders;
      };

      programs.ssh = {
        extraConfig = lib.concatMapStrings (id: ''
          Host ${aliasOf id}
            HostName ${hostNameOf id}
            Port ${toString port}
            HostKeyAlias ${hostNameOf id}
        '') remoteBuilders;

        knownHosts = lib.genAttrs remoteBuilders (id: {
          hostNames = [ (hostNameOf id) ];
          publicKey =
            cluster.hosts.${id}.labels.ssh_host_ed25519
              or (throw "nix-build-farm: builder ${id} needs labels.ssh_host_ed25519 in its inventory entry");
        });
      };
    })
  ];
}
